require "http/client"
require "xml"
require "./transport"

module XMPP
  # XEP-0206 / XEP-0124: XMPP over BOSH (HTTP long-polling). Presents a
  # classic XMPP byte stream; Session's writes are queued and flushed inside
  # the HTTP bodies that the read side issues, so a read may carry writes.
  class BoshTransport < Transport
    private BODY_NS       = "http://jabber.org/protocol/httpbind"
    private STREAM_NS     = "http://etherx.jabber.org/streams"
    private CLIENT_NS     = "jabber:client"
    private POLL_INTERVAL = 25.milliseconds

    @rid : UInt32

    getter tls_socket : OpenSSL::SSL::Socket::Client? = nil

    def initialize(@client : HTTP::Client, @endpoint : URI, @domain : String)
      @rid = (Random.rand(0xFFFFFFFE_u32) + 1).to_u32
      @sid = nil.as(String?)
      @pending = [] of String
      @pending_mutex = Mutex.new
      @stream_open_seen = false
      @restart_pending = false
      @terminate_pending = false
      @terminate_sent = false
      @eof = false
      @read_buffer = Transport::ReadBuffer.new
    end

    def self.open(config : Config, url : URI? = nil) : BoshTransport
      uri = resolve_url(config, url)
      scheme = uri.scheme
      tls = scheme == "https" ? TLSConnection.client_context(config) : nil
      host = uri.host.not_nil!
      port = uri.port || (tls ? 443 : 80)
      client = HTTP::Client.new(host, port, tls: tls)
      client.connect_timeout = config.connect_timeout.seconds
      new(client, uri, config.parsed_jid.domain)
    end

    def self.resolve_url(config : Config, url : URI? = nil) : URI
      explicit = url || config.url.try { |str| URI.parse(str) }
      if explicit
        unless explicit.scheme.in?("http", "https") && explicit.host
          raise ConfigurationError.new("BOSH URL must be http:// or https://, got: #{explicit}")
        end
        return explicit
      end
      URI.parse("https://#{config.parsed_jid.domain}:5280/http-bind")
    end

    def read(slice : Bytes) : Int32
      if (count = @read_buffer.drain(slice)) > 0
        return count
      end
      return 0 if @eof
      loop do
        bytes, terminated = fetch_chunk
        if terminated
          @eof = true
          return 0
        end
        if !bytes.empty?
          @read_buffer.push(bytes)
          if (count = @read_buffer.drain(slice)) > 0
            return count
          end
        else
          sleep POLL_INTERVAL
        end
      end
    end

    def write(slice : Bytes) : Nil
      data = String.new(slice)
      case Transport.classify_outbound(data)
      when :stream_open
        if @stream_open_seen
          @restart_pending = true
        else
          @stream_open_seen = true
        end
      when :stream_close
        @terminate_pending = true
      when :keepalive
        # The long-poll itself keeps the connection alive.
      when :stanza
        @pending_mutex.synchronize { @pending << data }
      end
    end

    def close
      @eof = true
      send_terminate
      @client.close
    end

    def closed? : Bool
      @eof
    end

    def encrypted? : Bool
      @endpoint.scheme == "https"
    end

    private def fetch_chunk : Tuple(String, Bool)
      if @sid.nil?
        create_session
      else
        perform_request
      end
    end

    private def create_session : Tuple(String, Bool)
      rid = next_rid
      body = String.build do |str|
        str << "<body xmlns='#{BODY_NS}' rid='#{rid}' to='#{@domain}' xml:lang='en'"
        str << " wait='1' hold='1' ver='1.6' xmpp:version='1.0' xmlns:xmpp='urn:xmpp:xbosh'/>"
      end
      root = parse_body(post(body))
      sid = root["sid"]?
      raise ProtocolError.new("BOSH session-create response is missing sid") unless sid
      @sid = sid
      return {"", true} if root["type"]? == "terminate"
      {assemble(true, root), false}
    end

    private def perform_request : Tuple(String, Bool)
      payload = @pending_mutex.synchronize do
        queued = @pending.dup
        @pending.clear
        queued
      end
      restart = @restart_pending
      @restart_pending = false
      terminate = @terminate_pending
      @terminate_pending = false

      body = String.build do |str|
        str << "<body xmlns='#{BODY_NS}' rid='#{next_rid}' sid='#{@sid}'"
        str << " type='terminate'" if terminate
        if restart
          str << " xmpp:restart='true' xmlns:xmpp='urn:xmpp:xbosh'"
        end
        str << ">"
        payload.each { |load| str << load }
        str << "</body>"
      end

      root = parse_body(post(body))
      return {"", true} if root["type"]? == "terminate"
      {assemble(false, root), false}
    end

    private def assemble(first : Bool, root : XML::Node) : String
      children = root.children.select(&.element?).map(&.to_s)
      String.build do |str|
        str << "<stream:stream xmlns='#{CLIENT_NS}' xmlns:stream='#{STREAM_NS}'>" if first
        children.each { |child| str << child }
      end
    end

    private def post(body : String) : HTTP::Client::Response
      @client.post(
        @endpoint.request_target || "/",
        HTTP::Headers{"Content-Type" => "text/xml; charset=utf-8", "Accept" => "text/xml"},
        body
      )
    rescue ex : IO::Error | Socket::Error
      raise ConnectionError.new("BOSH request failed: #{ex.message}")
    rescue ex : OpenSSL::SSL::Error
      message = ex.message || "BOSH request failed"
      if @endpoint.scheme == "https" && TLSConnection.verification_failure?(message)
        raise TLSVerificationError.new("BOSH TLS certificate or hostname verification failed: #{message}")
      end
      raise ConnectionError.new("BOSH request failed: #{message}")
    end

    private def parse_body(response : HTTP::Client::Response) : XML::Node
      unless response.status.success?
        raise ConnectionError.new("BOSH request failed with HTTP status #{response.status.code}")
      end
      root = XML.parse(response.body).first_element_child
      raise ProtocolError.new("BOSH response is not a <body> element") unless root && root.name == "body"
      root
    rescue ex : XML::Error
      raise ProtocolError.new("Malformed BOSH response: #{ex.message}")
    end

    private def next_rid : UInt32
      @rid += 1
      @rid
    end

    private def send_terminate
      sid = @sid
      return unless sid
      return if @terminate_sent
      @terminate_sent = true
      body = "<body xmlns='#{BODY_NS}' rid='#{next_rid}' sid='#{sid}' type='terminate'/>"
      @client.post(
        @endpoint.request_target || "/",
        HTTP::Headers{"Content-Type" => "text/xml; charset=utf-8"},
        body
      )
    rescue IO::Error | Socket::Error | ConnectionError
      # Best-effort: the server will expire the session on its own.
    end
  end
end
