require "socket"
require "openssl"
require "./event_manager"

module XMPP
  # Client is the main structure used to connect as a client on an XMPP
  # server.

  class Client
    include StreamClient
    # Track and broadcast connection state
    include EventManager
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

    # Resume attempts resuming  a Stream Managed session, based on the provided stream management state
    def resume(state : SMState)
      socket = TCPSocket.new(@config.host, @config.port, connect_timeout: @config.connect_timeout)
      socket.tcp_keepalive_interval = 30
      socket.sync = true
      update_state ConnectionState::Connected
      @socket = socket
      # Client is ok, we now open XMPP session
      @session = Session.new(socket, @config, state)
      update_state ConnectionState::SessionEstablished
      @supports_ping = @session.supports_ping
      # Start the keepalive fiber
      keepalive_quit = Channel(String).new(1)

      keep_alive_proc = ->(io : IO, c : Channel(String)) {
        spawn do
          keepalive(io, c)
        end
      }
      keep_alive_proc.call(socket, keepalive_quit)

      # Start the receiver fiber
      recv_proc = ->(s : SMState, c : Channel(String)) do
        spawn do
          recv(s, c)
        end
      end
      recv_proc.call(@session.sm_state, keepalive_quit)
      # We're connected and can now receive and send messages.
      # @session.stream_logger << "<presence xml:lang='en'><show>%s</show><status>%s</status></presence>", "chat", "Online")
      # TODO: Do we always want to send initial presence automatically ?
      # Do we need an option to avoid that or do we rely on client to send the presence itself ?
      send_with_logger "<presence xml:lang='en'/>"
    end

    def disconnect
      send("</stream:stream>")
      # TODO: Add a way to wait for stream close acknowledgement from the server for clean disconnect
      @socket.try &.close
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
      if (socket = @socket) && !socket.closed?
        send_with_logger packet
      else
        raise "Client is not connected"
      end
    end

    private def send_with_logger(packet : String)
      @session.send packet
    end

    # Loop: Receive data from server
    private def recv(state : SMState, keepalive_quit : Channel(String))
      loop do
        begin
          node = @session.read_resp
          val = Stanza::Parser.next_packet node
        rescue ex
          next if ex.message.try &.includes?("SSL_read: error:1409442E:SSL routines:ssl3_read_bytes:tlsv1 alert protocol version")
          keepalive_quit.send("read_resp failed - #{ex.message}")
          disconnected(state)
          Logger.error ex
          return
        end
        # Handle stream errors
        case val
        when .is_a?(Stanza::StreamError)
          Logger.debug "Stanza::StreamError received"
          Logger.debug val
          @router.route self, val
          keepalive_quit.send("Stanza::StreamError received")
          packet = val.as(Stanza::StreamError)
          name = packet.error.try &.xml_name.local
          stream_error name || "", packet.text
          return
        when .is_a?(Stanza::SMRequest) # Process Stream management nonzas
          answer = Stanza::SMAnswer.new
          answer.h = state.inbound == 0_u32 ? 1_u32 : state.inbound
          begin
            send answer
          rescue ex
            Logger.error ex
          end
        else
          state.inbound += 1
        end
        @router.route self, val
      end
    end

    # Loop: send whitespace keepalive to server
    # This is use to keep the connection open, but also to detect connection loss
    # and trigger proper client connection shutdown
    private def keepalive(conn, quit)
      Logger.info "Starting Keep Alive Fiber"
      ticker = Ticker.new(30)
      ticker.start
      loop do
        index, _ = Channel.select(ticker.receive_select_action,
          quit.receive_select_action)
        case index
        when 0
          begin
            if @supports_ping
              Logger.info "Sending Ping to keep connection active"
              iq = Stanza::IQ.new
              iq.type = "get"
              iq.id = @session.packet_id
              iq.to = @config.parsed_jid.domain
              iq.from = @config.parsed_jid.to_s
              iq.payload = Stanza::Ping.new
              send iq
            else
              Logger.info "Sending whitespace to keep connection active"
              conn << "\n"
              conn.flush
            end
            ticker.restart # Reset the timer
          rescue ex
            # when keep alive fails, we force close the connection
            Logger.error ex
            conn.close
            break
          end
        when 1
          break
        end
      end
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
