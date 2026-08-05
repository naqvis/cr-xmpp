require "xml"
require "openssl"
require "./config"
require "./auth"
require "./stanza"
require "./tls"
require "./transport/transport"

module XMPP
  class Session
    private STREAM_OPEN = "<?xml version='1.0'?><stream:stream to='%s' xmlns='%s' xmlns:stream='%s' xml:lang='en' version='1.0'>"
    private BUFFER_SIZE = 8024

    getter bind_jid : String # Jabber ID as provided by XMPP server
    getter stream_id : String
    getter sm_state : SMState
    getter features : Stanza::StreamFeatures
    getter? tls_enabled : Bool = false
    getter? resumed : Bool = false
    getter last_packet_id : Int32 = 0
    @skip_cert_verify : Bool = false

    # TLS introspection (RFC 7590 §3.6): the negotiated TLS version, cipher
    # suite, and whether the peer certificate was verified. Nil when the
    # connection is not encrypted.
    def tls_version : String?
      tls_socket.try &.tls_version
    end

    def cipher : String?
      tls_socket.try &.cipher
    end

    def tls_verified? : Bool
      !tls_socket.nil? && !@skip_cert_verify
    end

    private def tls_socket : OpenSSL::SSL::Socket::Client?
      case logger = @stream_logger
      when StreamLogger
        logger.tls_socket
      end
    end

    # Read/Write
    @stream_logger : IO
    @stream_reader : XMLStreamReader

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
      @stream_reader = XMLStreamReader.new(@stream_logger)
      @skip_cert_verify = false
    end

    def initialize(io, config : Config, @sm_state, encrypted : Bool = false)
      @connected = !io.closed?
      @bind_jid = ""
      @stream_id = ""
      @xmlns = ""
      if io.is_a?(IO::Buffered)
        io.sync = false
      end
      @stream_logger = StreamLogger.new(io, config.log_file)
      @stream_reader = XMLStreamReader.new(@stream_logger, config.max_stanza_size)

      # XEP-0368: a client-side pre-wrapped TLS socket means direct TLS, so
      # STARTTLS MUST NOT be negotiated. WebSocket/BOSH transports already
      # carry TLS (or handle it themselves), so they must not STARTTLS either.
      direct_tls = if io.is_a?(Transport)
                     !io.tls_socket.nil?
                   else
                     io.is_a?(OpenSSL::SSL::Socket::Client)
                   end
      @tls_enabled = encrypted || direct_tls
      @skip_cert_verify = config.skip_cert_verify?
      tls_conn = io

      @features = open config.parsed_jid.domain

      unless encrypted || direct_tls
        if @features.tls_required && !config.tls?
          raise TLSUnavailableError.new("Server requires TLS but TLS is disabled in the client configuration")
        end

        # RFC 7590 §3.1 anti-stripping: attempt STARTTLS even when the server
        # does not advertise it. Only a real negotiation failure aborts.
        # WebSocket/BOSH transports have no STARTTLS upgrade, so skip the
        # attempt entirely on them.
        starttls_eligible = io.is_a?(Transport) ? io.supports_starttls? : true
        if config.tls? && starttls_eligible
          tls_conn = start_tls_if_supported io, config
          if tls_conn.is_a?(IO::Buffered)
            tls_conn.sync = false
          end
          raise TLSNegotiationError.new("Failed to negotiate TLS session") unless tls_enabled?
        end
        reset(io, tls_conn, config) if tls_enabled?
      end

      # auth
      bind2_jid, used_sasl2 = auth config
      if used_sasl2
        # XEP-0388 sends the authenticated stream's features immediately after
        # <success/> without restarting the stream.
        @features = Stanza::StreamFeatures.new(read_resp)
      else
        reset(tls_conn, tls_conn, config)
      end

      if bind2_jid
        @bind_jid = bind2_jid
      else
        # attemp resumption
        if resume config
          @resumed = true
          return
        end

        # otherwise, bind resource and 'start' XMPP session
        bind config
        rfc_3921_session config
      end

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
      if disco = @disco_info
        disco.features.each do |feat|
          return true if feat.var == "urn:xmpp:ping"
        end
      end
      false
    end

    private def reset(conn, new_conn, o)
      set_stream_logger conn, new_conn, o
      @features = open o.parsed_jid.domain
    end

    private def set_stream_logger(conn, new_conn, o)
      unless conn == new_conn
        @stream_logger = StreamLogger.new(new_conn, o.log_file)
        @stream_reader = XMLStreamReader.new(@stream_logger, o.max_stanza_size)
      end
    end

    protected def read_resp
      @stream_reader.read_node
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
      child = if node.children.size > 0
                node.children[0]
              else
                read_resp
              end
      Stanza::StreamFeatures.new child # read_resp # node.children[0]
    end

    private def start_tls_if_supported(socket, o)
      advertised, _ = @features.does_start_tls
      if !advertised && o.tls?
        # RFC 7590 §3.1: attempt STARTTLS even when the server does not
        # advertise it, so a downgrade attack cannot silently strip encryption.
        Logger.warn "Server did not advertise STARTTLS; attempting anyway to prevent TLS stripping (RFC 7590 §3.1)"
      end
      if o.tls?
        send "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>"
        begin
          Stanza::TLSProceed.new read_resp
        rescue ex
          raise TLSNegotiationError.new("Expected STARTTLS proceed response: #{ex.message}")
        end
        tls_conn = TLSConnection.wrap(socket, o, o.parsed_jid.domain)
        @tls_enabled = true
        return tls_conn
      end
      # If we do not allow cleartext connections, make it explicit that server do not support starttls
      raise TLSUnavailableError.new("XMPP server does not advertise STARTTLS") if o.tls?

      # starttls is not supported => we do not upgrade the connection
      socket
    end

    private def auth(o)
      # Pass TLS socket if available for channel binding support
      tls_socket = @stream_logger.is_a?(StreamLogger) ? @stream_logger.as(StreamLogger).tls_socket : nil
      tls_verified = !tls_socket.nil? && !o.skip_cert_verify?
      auth = AuthHandler.new(
        @stream_logger,
        @stream_reader,
        @features,
        o.password,
        o.parsed_jid,
        tls_socket,
        tls_verified,
        request_bind2: !@sm_state.can_resume?
      )
      auth.authenticate o.sasl_auth_order
      {auth.bound_jid, auth.used_sasl2?}
    end

    private def resume(o)
      return false unless @features.does_stream_management
      return false unless @sm_state.can_resume?

      xml = sprintf "<resume xmlns='%s' h='%d' previd='%s'/>",
        Stanza::NS_STREAM_MANAGEMENT, @sm_state.inbound, @sm_state.id

      send xml
      packet = Stanza::Parser.next_packet read_resp
      if packet.is_a?(Stanza::SMResumed)
        p = packet.as(Stanza::SMResumed)
        if p.prev_id != @sm_state.id
          @sm_state = SMState.new
          raise StreamManagementError.new("session resumption returned a mismatched id")
        end
        # The server's h acknowledges stanzas handled from this client; it is
        # unrelated to our inbound counter.
        @sm_state.process_ack(p.h)
        @sm_state.touch # Update timestamp on successful resume
        return true
      elsif packet.is_a?(Stanza::SMFailed)
        p = packet.as(Stanza::SMFailed)
        # Store error information for later inspection
        error_msg = "SM resume failed: #{p.error_description}"
        @sm_state.error = error_msg
        Logger.debug error_msg
      else
        raise StreamManagementError.new("unexpected reply to stream-management resume")
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

      # Validate bind response
      raise ProtocolError.new("bind response must be type 'result', got: #{iq.type}") unless iq.type == "result"

      if payload = iq.payload.as?(Stanza::Bind)
        raise ProtocolError.new("bind response missing JID") if payload.jid.blank?
        @bind_jid = payload.jid # our local id (with possibly randomly generated resource)
      else
        raise ProtocolError.new("IQ bind result missing or invalid payload")
      end
    end

    # After the bind, if the session is not optional (as per old RFC 3921), we send the session open iq.
    private def rfc_3921_session(o)
      # We only negotiate session binding if it is mandatory, we skip it when optional.
      unless @features.session.try &.optional?
        xml = sprintf "<iq type='set' id='%s'><session xmlns='%s'/></iq>", packet_id, Stanza::NS_SESSION
        send xml
        begin
          Stanza::IQ.new read_resp
        rescue ex
          raise ProtocolError.new("expected IQ result after session open: #{ex.message}")
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
        # Store all SM state including location and max for resumption
        @sm_state = SMState.new(
          id: p.id,
          location: p.location,
          max: p.max,
          timestamp: Time.utc
        )
        Logger.debug "Stream Management enabled: id=#{p.id}, location=#{p.location}, max=#{p.max}"
      elsif packet.is_a?(Stanza::SMFailed)
        p = packet.as(Stanza::SMFailed)
        # Store error information for later inspection
        error_msg = "SM enable failed: #{p.error_description}"
        @sm_state.error = error_msg
        Logger.warn error_msg
      else
        raise StreamManagementError.new("unexpected reply to stream-management enable")
      end
    end

    # Query server support
    private def query_support(o : Config)
      iq = Stanza::IQ.new
      iq.type = "get"
      iq.id = "disco1"
      iq.to = o.parsed_jid.domain
      iq.from = @bind_jid.blank? ? o.parsed_jid.to_s : @bind_jid
      iq.disco_info
      xml = iq.to_xml
      stream_managed = !@sm_state.id.blank?
      # Stream management is enabled before this synchronous discovery
      # exchange. Account for both directions even though the Client receiver
      # and its ordinary send tracker are not running yet.
      @sm_state.queue_stanza(xml) if stream_managed
      send xml
      # The server may interleave stream-management acknowledgement nonzas
      # (<a/>/<r/>) before the result (observed on WebSocket, where the peer
      # acks the discovery request in its own frame); skip them.
      iq = loop do
        packet = Stanza::Parser.next_packet read_resp
        case packet
        when Stanza::IQ
          break packet.as(Stanza::IQ)
        when Stanza::SMAnswer, Stanza::SMRequest
          next
        else
          raise ProtocolError.new("expected disco IQ result, got #{packet.class}: #{packet.name}")
        end
      end
      if stream_managed
        @sm_state.inbound &+= 1_u32
        # Receiving the correlated IQ result proves that the server handled
        # this request. Advance the local acknowledgement baseline so later
        # XEP-0198 h values retain their correct sequence numbers.
        @sm_state.process_ack(@sm_state.outbound)
      end
      @disco_info = iq.payload.as?(Stanza::DiscoInfo)
    end
  end
end
