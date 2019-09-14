require "xml"
require "openssl"
require "./config"
require "./auth"
require "./stanza"

module XMPP
  class Session
    private STREAM_OPEN = "<?xml version='1.0'?><stream:stream to='%s' xmlns='%s' xmlns:stream='%s' xml:lang='en' version='1.0'>"
    private BUFFER_SIZE = 8024

    getter bind_jid : String # Jabber ID as provided by XMPP server
    getter stream_id : String
    getter sm_state : SMState
    getter features : Stanza::StreamFeatures
    getter tls_enabled : Bool = false
    getter last_packet_id : Int32 = 0

    # Read/Write
    @stream_logger : IO

    # Service Discovery Info
    @disco_info : Stanza::DiscoInfo? = nil

    protected def initialize
      @connected = false
      @bind_jid = ""
      @stream_id = ""
      @xmlns = ""
      @sm_state = SMState.new
      @features = Stanza::StreamFeatures.new
      @stream_logger = STDOUT
    end

    def initialize(io, config : Config, @sm_state)
      @connected = !io.closed?
      @bind_jid = ""
      @stream_id = ""
      @xmlns = ""
      if io.is_a?(IO::Buffered)
        io.sync = false
      end
      @stream_logger = StreamLogger.new(io, config.log_file)
      @features = open config.parsed_jid.domain

      ok = @features.tls_required
      if ok && !config.tls
        raise AuthenticationError.new "Server requires TLS session. Ensure you either 'tls' attribute of config to 'true'"
      end

      _, ok = @features.does_start_tls
      if config.tls && !ok
        raise AuthenticationError.new "You requested TLS session, but Server doesn't support TLS"
      end

      # starttls
      if ok && config.tls
        tls_conn = start_tls_if_supported io, config
        if tls_conn.is_a?(IO::Buffered)
          tls_conn.sync = false
        end
        raise AuthenticationError.new "Failed to negotiate TLS session" unless @tls_enabled
      else
        tls_conn = io
      end
      reset(io, tls_conn, config) if @tls_enabled

      # auth
      auth config
      reset(tls_conn, tls_conn, config)

      # attemp resumption
      return if resume config

      # otherwise, bind resource and 'start' XMPP session
      bind config
      rfc_3921_session config

      # Enable stream management if supported
      enable_stream_management config

      # Determine support
      query_support config
    end

    def packet_id
      @last_packet_id += 1
      sprintf "%x", @last_packet_id
    end

    protected def supports_ping
      if (disco = @disco_info)
        disco.features.each do |f|
          return true if f.var == "urn:xmpp:ping"
        end
      end
      false
    end

    private def reset(conn, new_conn, o)
      set_stream_logger conn, new_conn, o
      @features = open o.parsed_jid.domain
    end

    private def set_stream_logger(conn, new_conn, o)
      @stream_logger = StreamLogger.new(new_conn, o.log_file) unless conn == new_conn
    end

    protected def read_resp
      b = Bytes.new(BUFFER_SIZE)
      n = @stream_logger.read(b)
      raise ConnectionClosed.new "connection closed" if @stream_logger.closed? || n == 0
      xml = String.new(b[0, n])
      document = XML.parse(xml)
      if (r = document.first_element_child)
        r
      else
        raise "Invalid response from server: #{document.to_xml}"
      end
    end

    protected def send(xml)
      Logger.warn "Socket not connected" unless @connected
      return unless @connected
      @stream_logger.write xml.to_slice
    end

    private def open(domain)
      # Send stream open tag
      xml = sprintf STREAM_OPEN, domain, Stanza::NS_CLIENT, Stanza::NS_STREAM
      send xml

      # Set xml decoder and extract streamID from reply
      node = read_resp
      @stream_id, @xmlns = (Stanza::Parser.init_stream node)
      Stanza::StreamFeatures.new read_resp # node.children[0]
    end

    private def start_tls_if_supported(socket, o)
      _, ok = @features.does_start_tls
      if (ok)
        send "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>"
        begin
          Stanza::TLSProceed.new read_resp
        rescue ex
          raise AuthenticationError.new "expecting starttls proceed: #{ex.message}"
        end
        # Conert existing connection to TLS
        context = OpenSSL::SSL::Context::Client.new

        context.verify_mode = OpenSSL::SSL::VerifyMode::None if o.skip_cert_verify
        begin
          tls_conn = OpenSSL::SSL::Socket::Client.new(socket, context)
          tls_conn.sync = true
        rescue ex
          # don't leak the TCP socket when the SSL connection failed
          socket.close
          raise ex
        end
        @tls_enabled = true
        socket = tls_conn
        return tls_conn
      end
      # If we do not allow cleartext connections, make it explicit that server do not support starttls
      raise AuthenticationError.new "XMPP server does not advertise support for starttls" if o.tls

      # starttls is not supported => we do not upgrade the connection
      socket
    end

    private def auth(o)
      auth = AuthHandler.new(@stream_logger, @features, o.password, o.parsed_jid)
      auth.authenticate o.sasl_auth_order
    end

    private def resume(o)
      return false unless @features.does_stream_management
      return false if @sm_state.id.blank?
      xml = sprintf "<resume xmlns='%s' h='%d' previd='%s'/>",
        Stanza::NS_STREAM_MANAGEMENT, @sm_state.inbound, @sm_state.id

      send xml
      packet = Stanza::Parser.next_packet read_resp
      if packet.is_a?(Stanza::SMResumed)
        p = packet.as(Stanza::SMResumed)
        if p.prev_id != @sm_state.id
          @sm_state = SMState.new
          raise "session resumption: mismatched id"
        end
        @sm_state.inbound = p.h
        return true
      elsif packet.is_a?(Stanza::SMFailed)
        # do nothing
      else
        raise "unexpected reply to SM resume"
      end
      false
    end

    private def bind(o)
      # Send IQ message asking to bind to the local user name.
      resource = o.parsed_jid.resource || ""
      xml = sprintf "<iq type='set' id='%s'><bind xmlns='%s'/></iq>", packet_id, Stanza::NS_BIND
      if !resource.blank?
        xml = sprintf "<iq type='set' id='%s'><bind xmlns='%s'><resource>%s</resource></bind></iq>",
          packet_id, Stanza::NS_BIND, resource
      end

      send xml
      iq = Stanza::IQ.new read_resp

      # TODO check all elements
      if (payload = iq.payload.as?(Stanza::Bind))
        @bind_jid = payload.jid # our local id (with possibly randomly generated resource)
      else
        raise "iq bind result missing"
      end
    end

    # After the bind, if the session is not optional (as per old RFC 3921), we send the session open iq.
    private def rfc_3921_session(o)
      # We only negotiate session binding if it is mandatory, we skip it when optional.
      unless @features.session.try &.optional
        xml = sprintf "<iq type='set' id='%s'><session xmlns='%s'/></iq>", packet_id, Stanza::NS_SESSION
        send xml
        begin
          Stanza::IQ.new read_resp
        rescue ex
          raise "expecting iq result after session open: #{ex.message}"
        end
      end
    end

    # Enable stream management, with session resumption, if supported.
    private def enable_stream_management(o : Config)
      return unless @features.does_stream_management
      xml = sprintf "<enable xmlns='%s' resume='true'/>", Stanza::NS_STREAM_MANAGEMENT
      send xml
      packet = Stanza::Parser.next_packet read_resp
      if packet.is_a?(Stanza::SMEnabled)
        p = packet.as(Stanza::SMEnabled)
        @sm_state = SMState.new(id: p.id)
      elsif packet.is_a?(Stanza::SMFailed)
        # TODO: Store error in SMState, for later inspection
      else
        raise "unexpected reply to SM enable"
      end
    end

    # Query server support
    private def query_support(o : Config)
      iq = Stanza::IQ.new
      iq.type = "get"
      iq.id = "disco1"
      iq.to = o.parsed_jid.domain
      iq.from = o.parsed_jid.to_s
      iq.disco_info
      send iq.to_xml
      iq = Stanza::IQ.new read_resp
      @disco_info = iq.payload.as?(Stanza::DiscoInfo)
    end
  end
end
