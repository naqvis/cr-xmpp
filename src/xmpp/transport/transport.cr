require "../config"
require "../connection"
require "../tls"
require "../event_manager"
require "../alt_connections"

module XMPP
  # A transport presents a classic XMPP byte stream (`<stream:stream>` in,
  # top-level elements out) over the underlying connection protocol. `Session`
  # and `XMLStreamReader` read and write complete logical elements through this
  # single abstraction, so SASL, stream management, and auth are untouched.
  abstract class Transport < ::IO
    # Ordered byte buffer that inbound messages are appended to and that
    # `#read` drains from. A single read request may be served from several
    # messages and a message may span several reads.
    class ReadBuffer
      def initialize
        @buffer = IO::Memory.new
        @pos = 0
      end

      def push(data : String)
        @buffer.write(data.to_slice)
      end

      def push(data : Bytes)
        @buffer.write(data)
      end

      def drain(slice : Bytes) : Int32
        return 0 if @pos >= @buffer.size
        remaining = @buffer.size - @pos
        count = Math.min(slice.size, remaining)
        slice.copy_from(@buffer.to_slice[@pos, count])
        @pos += count
        if @pos == @buffer.size
          @buffer.clear
          @pos = 0
        end
        count
      end

      def empty? : Bool
        @pos >= @buffer.size
      end
    end

    # True when TLS is already handled at or below this transport, so the
    # session must not attempt a STARTTLS upgrade.
    abstract def encrypted? : Bool

    # The underlying TLS socket when the transport opened one directly
    # (XEP-0368 direct TLS). Nil for plaintext, STARTTLS-managed, WebSocket,
    # and BOSH transports.
    abstract def tls_socket : OpenSSL::SSL::Socket::Client?

    # Whether the session must negotiate a STARTTLS upgrade on this transport
    # before authentication. Only a plaintext TCP stream does; WebSocket and
    # BOSH transports have no STARTTLS (their security is fixed at connection
    # time by ws/wss or http/https), so the RFC 7590 anti-stripping attempt
    # must not run against them.
    def supports_starttls? : Bool
      false
    end

    def self.connect(config : Config) : Transport
      case config.transport
      in TransportMode::Tcp       then TcpTransport.open(config)
      in TransportMode::WebSocket then WebSocketTransport.open(config)
      in TransportMode::Bosh      then BoshTransport.open(config)
      in TransportMode::Auto      then AutoTransport.open(config)
      end
    end

    # Classifies one outbound write from the session into the logical units
    # the message transports care about.
    def self.classify_outbound(data : String) : Symbol
      trimmed = data.strip
      return :keepalive if trimmed.empty?
      return :stream_close if trimmed.starts_with?("</")
      return :stream_open if trimmed.includes?("<stream:stream")
      :stanza
    end

    def self.extract_attribute(xml : String, name : String) : String?
      match = xml.match(/#{Regex.escape(name)}=['"]([^'"]*)['"]/)
      match.try &.[1]
    end
  end

  # XEP-0156 fallback for `Config.transport = TransportMode::Auto`: try the
  # RFC 6120 TCP path first, then each discovered WebSocket/BOSH endpoint in
  # order. Returns the concrete transport that connected (never a wrapper).
  module AutoTransport
    # Block form lets callers intercept discovery (e.g. tests that assert TCP
    # succeeds without ever reaching host-meta).
    def self.open(config : Config, &discover : (String, Config) -> Array(AlternativeEndpoint)) : Transport
      open(config, discover)
    end

    def self.open(
      config : Config,
      discover : (String, Config) -> Array(AlternativeEndpoint) = ->(domain : String, conf : Config) { AltConnectionResolver.discover(domain, conf) },
    ) : Transport
      begin
        return TcpTransport.open(config)
      rescue ex : ConnectionError
      end

      endpoints = discover.call(config.parsed_jid.domain, config)
      if endpoints.empty?
        raise ConnectionError.new("no alternative connection endpoints discovered for #{config.parsed_jid.domain}")
      end

      last_error = nil.as(Exception?)
      endpoints.each do |endpoint|
        begin
          case endpoint.kind
          in EndpointKind::WebSocket
            return WebSocketTransport.open(config, url: endpoint.url)
          in EndpointKind::Bosh
            return BoshTransport.open(config, url: endpoint.url)
          end
        rescue ex : ConnectionError
          last_error = ex
        end
      end
      raise ConnectionError.new(
        "unable to connect via any discovered endpoint#{last_error ? ": #{last_error.message}" : ""}"
      )
    end
  end
end
