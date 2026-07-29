require "socket"
require "openssl"
require "./event_manager"
require "./stream_management"

module XMPP
  private class ClientConnection
    getter socket : TCPSocket
    getter session : Session
    getter state : SMState
    getter stop : Channel(Nil)
    getter receiver_done : Channel(Nil)
    getter shutdown_done : Channel(Nil)

    @mutex = Mutex.new
    @stopping = false
    @intentional_shutdown = false
    @disconnect_notified = false
    @finished = false

    def initialize(@socket, @session, @state)
      @stop = Channel(Nil).new
      @receiver_done = Channel(Nil).new(1)
      @shutdown_done = Channel(Nil).new
    end

    # Returns true only to the fiber that initiated shutdown.
    def request_stop(intentional : Bool) : Bool
      close_channel = @mutex.synchronize do
        @intentional_shutdown ||= intentional
        next false if @stopping
        @stopping = true
        true
      end
      @stop.close if close_channel
      close_channel
    end

    def stopping? : Bool
      @mutex.synchronize { @stopping }
    end

    def intentional_shutdown? : Bool
      @mutex.synchronize { @intentional_shutdown }
    end

    def mark_disconnect_notified : Bool
      @mutex.synchronize do
        next false if @disconnect_notified
        @disconnect_notified = true
        true
      end
    end

    def mark_finished
      close_channel = @mutex.synchronize do
        next false if @finished
        @finished = true
        true
      end
      @shutdown_done.close if close_channel
    end
  end

  # Client is the main structure used to connect as a client on an XMPP
  # server.

  class Client
    include StreamClient
    # Track and broadcast connection state
    include EventManager
    # Stream Management support
    include StreamManagement
    # Store user defined options and states
    @config : Config
    # Session gathers data that be access by users of this Shard
    getter session : Session
    # TCP level connection / can be replaced by a TLS session after starttls
    {% if flag?(:without_openssl) %}
      @socket : TCPSocket | Nil
    {% else %}
      @socket : TCPSocket | OpenSSL::SSL::Socket | Nil
    {% end %}

    # Router is used to dispatch packets
    @router : Router

    # server support for ping
    @supports_ping : Bool = false
    @connection : ClientConnection? = nil
    @connection_mutex = Mutex.new
    @write_mutex = Mutex.new
    @connecting = false
    @connect_cancelled = false

    def initialize(@config, @router)
      @session = Session.new
      # Register ping handler
      @router.route(->pong(Sender, Stanza::Packet)).iq_namespaces(["urn:xmpp:ping"])
    end

    # connect triggers actual TCP connection, based on previously defined parameters.
    # connect simply triggers resumption, with an empty session state.
    def connect
      resume SMState.new
    end

    def unacknowledged_stanza_count : Int32
      @session.sm_state.unacked_count
    end

    def last_resume_succeeded? : Bool
      @session.resumed?
    end

    # Resume attempts resuming  a Stream Managed session, based on the provided stream management state
    def resume(state : SMState)
      begin_connect
      begin
        update_state ConnectionState::Connecting
        ensure_connect_not_cancelled
        socket = nil.as(TCPSocket?)
        connection = nil.as(ClientConnection?)

        socket = TCPSocket.new(@config.host, @config.port, connect_timeout: @config.connect_timeout)
        socket.tcp_keepalive_interval = 30
        socket.read_timeout = @config.io_timeout.seconds
        socket.write_timeout = @config.io_timeout.seconds
        socket.sync = true
        @connection_mutex.synchronize do
          raise ConnectionError.new("connection attempt was cancelled") if @connect_cancelled
          @socket = socket
        end
        update_state ConnectionState::Connected
        ensure_connect_not_cancelled

        # Client is ok, we now open XMPP session
        session = Session.new(socket, @config, state)
        ensure_connect_not_cancelled
        @session = session
        @supports_ping = session.supports_ping
        connection = ClientConnection.new(socket, session, session.sm_state)
        @connection_mutex.synchronize { @connection = connection }

        # Enable stream management tracking if SM is active
        if !session.sm_state.id.blank?
          enable_sm_tracking

          # If resuming, resend unacknowledged stanzas
          if session.sm_state.has_unacked_stanzas?
            Logger.info "Resuming session, resending unacknowledged stanzas"
            @write_mutex.synchronize { resend_unacked_stanzas }
          end
        else
          disable_sm_tracking
        end

        # We're connected and can now receive and send messages.
        # Send initial presence if auto_presence is enabled (default: true)
        # Users can disable this to manually control presence (e.g., for invisible login)
        if @config.auto_presence?
          write_to(connection, "<presence xml:lang='en'/>", track: false)
        end

        spawn { keepalive(connection) }
        spawn { recv(connection) }
        update_state ConnectionState::SessionEstablished
      rescue ex
        cleanup_failed_connect(connection, socket)
        raise ex
      ensure
        @connection_mutex.synchronize { @connecting = false }
      end
    end

    def disconnect
      connection, socket = @connection_mutex.synchronize do
        @connect_cancelled = true if @connecting
        {@connection, @socket}
      end
      unless connection
        socket.try { |open_socket| open_socket.close unless open_socket.closed? }
        update_state ConnectionState::Disconnected unless current_state.disconnected?
        return
      end

      owns_shutdown = connection.request_stop(intentional: true)
      unless owns_shutdown
        wait_for_shutdown(connection, timeout: 3.0)
        return
      end
      update_state ConnectionState::Disconnecting
      begin
        # Send closing stream tag
        write_to(connection, "</stream:stream>", track: false, allow_stopping: true)

        # The receiver fiber is the connection's sole reader. It observes the
        # peer's closing tag, avoiding concurrent reads from the same TLS stream.
        wait_for_receiver(connection, timeout: 3.0)
      rescue ex
        Logger.warn "Error during disconnect: #{ex.message}"
      ensure
        connection.socket.close unless connection.socket.closed?
        finish_connection(connection, notify: true)
      end
    end

    private def wait_for_receiver(connection : ClientConnection, timeout : Float64)
      select
      when connection.receiver_done.receive
        Logger.debug "Clean disconnect completed"
      when timeout(timeout.seconds)
        Logger.debug "Disconnect timeout reached, forcing close"
      end
    end

    private def wait_for_shutdown(connection : ClientConnection, timeout : Float64)
      select
      when connection.shutdown_done.receive?
      when timeout(timeout.seconds)
      end
    end

    # sends marshal's XMPP stanza and sends it to the server.
    def send(packet : Stanza::Packet)
      send packet.to_xml
    end

    # send sends an XMPP stanza as a string to the server.
    # It can be invalid XML or XMPP content. In that case, the server will
    # disconnect the client. It is up to the user of this method to
    # carefully craft the XML content to produce valid XMPP.
    def send(packet : String)
      connection = active_connection
      write_to(connection, packet, track: true)
    end

    # Loop: Receive data from server
    private def recv(connection : ClientConnection)
      state = connection.state
      loop do
        begin
          node = connection.session.read_resp
          val = Stanza::Parser.next_packet node

          # Handle stream errors
          case val
          when .is_a?(Stanza::StreamError)
            Logger.debug "Stanza::StreamError received"
            Logger.debug val
            @router.route self, val
            packet = val.as(Stanza::StreamError)
            name = packet.error.try &.xml_name.local
            stream_error name || "", packet.text
            finish_connection(connection, notify: false)
            return
          when .is_a?(Stanza::SMRequest) # Process Stream management nonzas
            answer = Stanza::SMAnswer.new
            answer.h = state.inbound
            send answer
          when .is_a?(Stanza::SMAnswer) # Process acknowledgement from server
            ack = val.as(Stanza::SMAnswer)
            process_sm_ack(ack.h)
          else
            state.inbound &+= 1_u32
          end
          @router.route self, val
        rescue ex
          unless connection.intentional_shutdown?
            Logger.error ex
            finish_connection(connection, notify: true, exception: ex)
          end
          return
        end
      end
    ensure
      connection.receiver_done.send(nil)
    end

    # Loop: send whitespace keepalive to server
    # This is use to keep the connection open, but also to detect connection loss
    # and trigger proper client connection shutdown
    private def keepalive(connection : ClientConnection)
      Logger.info "Starting Keep Alive Fiber"
      loop do
        select
        when connection.stop.receive?
          return
        when timeout(30.seconds)
          begin
            if @supports_ping
              Logger.info "Sending Ping to keep connection active"
              iq = Stanza::IQ.new
              iq.type = "get"
              iq.id = connection.session.packet_id
              iq.to = @config.parsed_jid.domain
              iq.from = @config.parsed_jid.to_s
              iq.payload = Stanza::Ping.new
              send iq
            else
              Logger.info "Sending whitespace to keep connection active"
              write_to(connection, "\n", track: false)
            end
          rescue ex
            Logger.error ex
            finish_connection(connection, notify: true, exception: ex) unless connection.intentional_shutdown?
            return
          end
        end
      end
    end

    private def begin_connect
      @connection_mutex.synchronize do
        if @connecting || (@connection && !@connection.not_nil!.stopping?)
          raise AlreadyConnectedError.new("client is already connected or connecting")
        end
        @connecting = true
        @connect_cancelled = false
      end
    end

    private def ensure_connect_not_cancelled
      cancelled = @connection_mutex.synchronize { @connect_cancelled }
      raise ConnectionError.new("connection attempt was cancelled") if cancelled
    end

    private def active_connection : ClientConnection
      @connection_mutex.synchronize do
        connection = @connection
        unless connection && !connection.stopping? && !connection.socket.closed?
          raise NotConnectedError.new("client is not connected")
        end
        connection
      end
    end

    private def write_to(
      connection : ClientConnection,
      packet : String,
      track : Bool,
      allow_stopping : Bool = false,
    )
      @write_mutex.synchronize do
        active = @connection_mutex.synchronize { @connection.try(&.same?(connection)) }
        unless active && !connection.socket.closed? && (allow_stopping || !connection.stopping?)
          raise NotConnectedError.new("client connection is no longer active")
        end

        if track && sm_enabled?
          send_with_sm packet
        else
          connection.session.send packet
        end
      end
    end

    private def cleanup_failed_connect(connection : ClientConnection?, socket : TCPSocket?)
      connection.try &.request_stop(intentional: true)
      socket.try { |open_socket| open_socket.close unless open_socket.closed? }
      @connection_mutex.synchronize do
        @connection = nil if connection && @connection.try(&.same?(connection))
        @socket = nil if socket && @socket.try(&.same?(socket))
      end
      disable_sm_tracking
      connection.try &.mark_finished
      set_current_state(ConnectionState::Disconnected)
    end

    private def finish_connection(
      connection : ClientConnection,
      notify : Bool,
      exception : Exception? = nil,
    )
      connection.request_stop(intentional: false)
      connection.socket.close unless connection.socket.closed?
      was_active = @connection_mutex.synchronize do
        next false unless @connection.try(&.same?(connection))
        @connection = nil
        @socket = nil
        true
      end
      if was_active
        disable_sm_tracking
        disconnected(connection.state, exception) if notify && connection.mark_disconnect_notified
      end
      connection.mark_finished
    end

    private def pong(s : Sender, p : Stanza::Packet)
      return unless p.is_a?(Stanza::IQ)
      iq = p.as(Stanza::IQ)
      resp = Stanza::IQ.new
      resp.from = iq.to
      resp.to = iq.from
      resp.type = "result"
      resp.id = iq.id
      send resp
    end
  end
end
