require "http/web_socket"
require "./transport"

module XMPP
  # RFC 7395: XMPP over WebSocket. Presents a classic XMPP byte stream to
  # Session while translating stream headers to <open/>/<close/> framing
  # elements and sending whitespace keepalives as WebSocket PING frames.
  class WebSocketTransport < Transport
    private FRAMING_NS    = "urn:ietf:params:xml:ns:xmpp-framing"
    private SUBPROTOCOL   = "xmpp"
    private STREAM_CLIENT = "jabber:client"
    private STREAM_NS     = "http://etherx.jabber.org/streams"

    getter tls_socket : OpenSSL::SSL::Socket::Client? = nil

    def initialize(@ws : HTTP::WebSocket, @domain : String, @encrypted : Bool)
      @read_buffer = Transport::ReadBuffer.new
      @eof = false
      @incoming = Channel(String).new
      spawn { reader_loop }
    end

    def self.open(config : Config, url : URI? = nil) : WebSocketTransport
      uri = resolve_url(config, url)
      ws = open_socket(uri, config)
      new(ws, config.parsed_jid.domain, uri.scheme == "wss")
    end

    def self.resolve_url(config : Config, url : URI? = nil) : URI
      explicit = url || config.url.try { |s| URI.parse(s) }
      if explicit
        unless explicit.scheme.in?("ws", "wss") && explicit.host
          raise ConfigurationError.new("websocket URL must be ws:// or wss://, got: #{explicit}")
        end
        return explicit
      end
      URI.parse("wss://#{config.parsed_jid.domain}/ws")
    end

    def self.open_socket(url : URI, config : Config) : HTTP::WebSocket
      host = url.host.not_nil!
      path = url.request_target || "/"
      tls = url.scheme == "wss" ? TLSConnection.client_context(config) : nil
      begin
        protocol = HTTP::WebSocket::Protocol.new(
          host, path, url.port, tls, HTTP::Headers.new, [SUBPROTOCOL]
        )
        HTTP::WebSocket.new(protocol)
      rescue ex : Socket::Error | OpenSSL::SSL::Error | IO::Error
        message = ex.message || "WebSocket handshake failed"
        if url.scheme == "wss" && TLSConnection.verification_failure?(message)
          raise TLSVerificationError.new("WebSocket TLS certificate or hostname verification failed: #{message}")
        end
        raise ConnectionError.new("WebSocket connection to #{url} failed: #{message}")
      end
    end

    def read(slice : Bytes) : Int32
      if (count = @read_buffer.drain(slice)) > 0
        return count
      end
      return 0 if @eof
      loop do
        chunk = @incoming.receive?
        break if chunk.nil?
        @read_buffer.push(chunk)
        if (count = @read_buffer.drain(slice)) > 0
          return count
        end
      end
      @eof = true
      0
    end

    def write(slice : Bytes) : Nil
      data = String.new(slice)
      case Transport.classify_outbound(data)
      when :stream_open
        domain = Transport.extract_attribute(data, "to") || @domain
        @ws.send("<open xmlns='#{FRAMING_NS}' to='#{domain}' xml:lang='en' version='1.0'/>")
      when :stream_close
        @ws.send("<close xmlns='#{FRAMING_NS}'/>")
        @ws.close
        @eof = true
      when :keepalive
        @ws.ping
      when :stanza
        @ws.send(qualify_stanza(data.strip))
      end
    end

    # RFC 7395: a WebSocket frame is a standalone XML fragment with no stream
    # element to inherit the default namespace from, so client stanzas must
    # declare xmlns='jabber:client' explicitly. Elements that already carry a
    # default xmlns (SASL2, stream management, TLS, ...) are left untouched.
    private def qualify_stanza(xml : String) : String
      return xml if root_has_xmlns?(xml)
      if match = xml.match(/\A<([^\s>\/]+)(\s|\/?>)/)
        name = match[1]
        separator = match[2]
        rest = match[0].size == xml.size ? "" : xml[match[0].size..]
        "<#{name} xmlns=\"#{STREAM_CLIENT}\"#{separator}#{rest}"
      else
        xml
      end
    end

    private def root_has_xmlns?(xml : String) : Bool
      quote = nil.as(Char?)
      xml.each_char_with_index do |char, index|
        if quote
          quote = nil if char == quote
        elsif char == '\'' || char == '"'
          quote = char
        elsif char == '>'
          return xml[0, index + 1].includes?("xmlns=")
        end
      end
      false
    end

    def close
      @ws.close
      @eof = true
    end

    def closed? : Bool
      @eof || @ws.closed?
    end

    def encrypted? : Bool
      @encrypted
    end

    private def reader_loop
      loop do
        message = @ws.receive?
        case message
        when String
          break unless push_inbound(message)
        when Bytes
          @incoming.send(String.new(message))
        when Nil
          @eof = true
          break
        end
      end
    rescue IO::Error | Socket::Error
      @eof = true
    ensure
      @incoming.close
    end

    private def push_inbound(message : String) : Bool
      trimmed = message.strip
      if trimmed.starts_with?("<open") && trimmed.includes?(FRAMING_NS)
        from = Transport.extract_attribute(trimmed, "from")
        id = Transport.extract_attribute(trimmed, "id")
        attrs = String.build do |b|
          b << " from='" << from << "'" if from
          b << " id='" << id << "'" if id
        end
        @incoming.send("<stream:stream xmlns='#{STREAM_CLIENT}' xmlns:stream='#{STREAM_NS}'#{attrs}>")
      elsif trimmed.starts_with?("<close") && trimmed.includes?(FRAMING_NS)
        @incoming.send("</stream:stream>")
        @eof = true
        return false
      else
        @incoming.send(message)
      end
      true
    end
  end
end
