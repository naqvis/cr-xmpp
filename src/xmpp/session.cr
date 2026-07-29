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
    getter? tls_enabled : Bool = false
    getter? resumed : Bool = false
    getter last_packet_id : Int32 = 0

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
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def initialize(io, config : Config, @sm_state)
      @connected = !io.closed?
      @bind_jid = ""
      @stream_id = ""
      @xmlns = ""
      if io.is_a?(IO::Buffered)
        io.sync = false
      end
      @stream_logger = StreamLogger.new(io, config.log_file)
      @stream_reader = XMLStreamReader.new(@stream_logger, config.max_stanza_size)
      @features = open config.parsed_jid.domain

      ok = @features.tls_required
      if ok && !config.tls?
        raise TLSUnavailableError.new("Server requires TLS but TLS is disabled in the client configuration")
      end

      _, ok = @features.does_start_tls
      if config.tls? && !ok
        raise TLSUnavailableError.new("TLS was requested but the XMPP server does not advertise STARTTLS")
      end

      # starttls
      if ok && config.tls?
        tls_conn = start_tls_if_supported io, config
        if tls_conn.is_a?(IO::Buffered)
          tls_conn.sync = false
        end
        raise TLSNegotiationError.new("Failed to negotiate TLS session") unless tls_enabled?
      else
        tls_conn = io
      end
      reset(io, tls_conn, config) if tls_enabled?

      # auth
      auth config
      reset(tls_conn, tls_conn, config) unless @features.sasl2_authentication

      # attemp resumption
      if resume config
        @resumed = true
        return
      end

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
      _, ok = @features.does_start_tls
      if ok
        send "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>"
        begin
          Stanza::TLSProceed.new read_resp
        rescue ex
          raise TLSNegotiationError.new("Expected STARTTLS proceed response: #{ex.message}")
        end
        # Conert existing connection to TLS
        context = OpenSSL::SSL::Context::Client.new
        context.add_options(
          OpenSSL::SSL::Options::NO_TLS_V1 |
          OpenSSL::SSL::Options::NO_TLS_V1_1
        )
        if ca_certificates = o.tls_ca_certificates
          context.ca_certificates = ca_certificates
        end
        if o.skip_cert_verify?
          Logger.warn "TLS certificate verification is disabled; this connection is vulnerable to impersonation"
          context.verify_mode = OpenSSL::SSL::VerifyMode::None
        end
        begin
          hostname = o.skip_cert_verify? ? nil : o.parsed_jid.domain
          tls_conn = OpenSSL::SSL::Socket::Client.new(socket, context, hostname: hostname)
          tls_conn.sync = true
        rescue ex : OpenSSL::SSL::Error
          # don't leak the TCP socket when the SSL connection failed
          socket.close
          message = ex.message || "TLS handshake failed"
          if !o.skip_cert_verify? && tls_verification_failure?(message)
            raise TLSVerificationError.new("TLS certificate or hostname verification failed: #{message}")
          end
          raise TLSNegotiationError.new("TLS handshake failed: #{message}")
        rescue ex
          socket.close
          raise ex
        end
        @tls_enabled = true
        socket = tls_conn
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
      auth = AuthHandler.new(@stream_logger, @stream_reader, @features, o.password, o.parsed_jid, tls_socket, tls_verified)
      auth.authenticate o.sasl_auth_order
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
      iq.from = o.parsed_jid.to_s
      iq.disco_info
      xml = iq.to_xml
      stream_managed = !@sm_state.id.blank?
      # Stream management is enabled before this synchronous discovery
      # exchange. Account for both directions even though the Client receiver
      # and its ordinary send tracker are not running yet.
      @sm_state.queue_stanza(xml) if stream_managed
      send xml
      iq = Stanza::IQ.new read_resp
      if stream_managed
        @sm_state.inbound &+= 1_u32
        # Receiving the correlated IQ result proves that the server handled
        # this request. Advance the local acknowledgement baseline so later
        # XEP-0198 h values retain their correct sequence numbers.
        @sm_state.process_ack(@sm_state.outbound)
      end
      @disco_info = iq.payload.as?(Stanza::DiscoInfo)
    end

    private def tls_verification_failure?(message : String) : Bool
      normalized = message.downcase
      normalized.includes?("certificate verify") ||
        normalized.includes?("hostname") ||
        normalized.includes?("does not match")
    end
  end
end
