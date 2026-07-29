require "./event_manager"
require "./component/disco"
require "./component/delegation"
require "./component/privilege"
require "./component/errors"
require "socket"
require "digest/sha1"

module XMPP
  private COMP_STREAM_OPEN = "<?xml version='1.0'?><stream:stream to='%s' xmlns='%s' xmlns:stream='%s'>"

  struct ComponentOptions
    # Component Connection Info
    # domain is the XMPP server subdomain that the component will handle
    getter domain : String
    # secret is the "password" used by the XMPP server to secure component access
    getter secret : String
    # host is the XMPP Host to connect to
    getter host : String
    # port is the XMPP host port to connect to
    getter port : Int32

    # Component discovery

    # component human readable name, that will be shown in XMPP discovery
    getter name : String
    # Typical categories and types: https://xmpp.org/registrar/disco-categories.html
    getter category : String
    getter type : String
    getter log_file : IO?
    getter connect_timeout : Int32
    getter io_timeout : Int32
    getter max_stanza_size : Int32

    # Communication with developer client / StreamManager

    def initialize(@domain, @secret, @host, @port, @name, @category, @type, @log_file = nil,
                   @connect_timeout = 5, @io_timeout = 30,
                   @max_stanza_size = XMLStreamReader::DEFAULT_MAX_ELEMENT_SIZE)
      raise ConfigurationError.new("connect_timeout must be positive") unless @connect_timeout > 0
      raise ConfigurationError.new("io_timeout must be positive") unless @io_timeout > 0
      raise ConfigurationError.new("max_stanza_size must be positive") unless @max_stanza_size > 0
    end
  end

  # Component implements an XMPP extension allowing to extend XMPP server
  # using external components. Component specifications are defined
  # in XEP-0114, XEP-0355 and XEP-0356.

  class Component
    include StreamClient
    # Track and broadcast connection state
    include EventManager
    # XEP-0030: Service Discovery
    include ComponentDisco
    # XEP-0355: Namespace Delegation
    include ComponentDelegation
    # XEP-0356: Privileged Entity
    include ComponentPrivilege

    getter options : ComponentOptions
    @router : Router
    @reader : XMLStreamReader?
    # TCP level connection
    @conn : IO?
    @connection_mutex = Mutex.new
    @write_mutex = Mutex.new
    @receiver_done : Channel(Nil)? = nil
    @connecting = false
    @connect_cancelled = false
    @intentional_shutdown = false
    @disconnect_notified = false
    # Service Discovery
    getter disco_info : ComponentDisco::DiscoInfo
    getter disco_items : ComponentDisco::DiscoItems

    def initialize(@options, @router)
      @xmlns = ""
      @disco_info = ComponentDisco::DiscoInfo.new
      @disco_items = ComponentDisco::DiscoItems.new

      # Add default identity from options
      @disco_info.add_identity(@options.category, @options.type, @options.name)

      # Setup automatic handlers
      setup_disco_handlers(@disco_info, @disco_items)
      setup_delegation_handlers
      setup_privilege_handlers
    end

    # connect triggers component connection to XMPP server component port.
    def connect
      @connection_mutex.synchronize do
        if @connecting || @conn.try { |conn| !conn.closed? }
          raise AlreadyConnectedError.new("component is already connected or connecting")
        end
        @connecting = true
        @connect_cancelled = false
        @intentional_shutdown = false
        @disconnect_notified = false
      end
      update_state ConnectionState::Connecting
      ensure_component_connect_not_cancelled

      socket = nil.as(TCPSocket?)
      conn = nil.as(IO?)
      begin
        socket = TCPSocket.new(@options.host, @options.port, connect_timeout: @options.connect_timeout)
        socket.read_timeout = @options.io_timeout.seconds
        socket.write_timeout = @options.io_timeout.seconds
        conn = StreamLogger.new(socket, @options.log_file)
        reader = XMLStreamReader.new(conn, @options.max_stanza_size)
        @connection_mutex.synchronize do
          raise ConnectionError.new("component connection attempt was cancelled") if @connect_cancelled
          @conn = conn
          @reader = reader
        end
        update_state ConnectionState::Connected
        ensure_component_connect_not_cancelled

        xml = sprintf COMP_STREAM_OPEN, @options.domain, Stanza::NS_COMPONENT, Stanza::NS_STREAM
        send xml
        stream_id, @xmlns = Stanza::Parser.init_stream(reader.read_node)
        raise ComponentError.new("Unable to retrieve stream id") if stream_id.blank?

        xml = sprintf "<handshake>%s</handshake>", hand_shake stream_id
        send xml
        val = Stanza::Parser.next_packet reader.read_node, @xmlns
        ensure_component_connect_not_cancelled

        case val
        when .is_a?(Stanza::StreamError)
          handle_stream_error(val.as(Stanza::StreamError))
        when .is_a?(Stanza::Handshake)
          done = Channel(Nil).new(1)
          @connection_mutex.synchronize { @receiver_done = done }
          spawn { recv(conn, reader, done) }
          update_state ConnectionState::SessionEstablished
        else
          raise ComponentError.new("expecting handshake result, got : #{val.name}")
        end
      rescue ex
        conn.try { |connection| connection.close unless connection.closed? }
        socket.try { |tcp| tcp.close unless tcp.closed? }
        clear_component_connection(conn)
        set_current_state(ConnectionState::Disconnected)
        raise ex
      ensure
        @connection_mutex.synchronize { @connecting = false }
      end
    end

    def resume(state : SMState)
      # components do not support stream management, so just call connect instead
      connect
    end

    def disconnect
      conn, done, already_stopping = @connection_mutex.synchronize do
        @connect_cancelled = true if @connecting
        connection = @conn
        stopping = @intentional_shutdown
        @intentional_shutdown = true if connection
        {connection, @receiver_done, stopping}
      end
      unless conn
        update_state ConnectionState::Disconnected unless current_state.disconnected?
        return
      end
      return if already_stopping

      update_state ConnectionState::Disconnecting
      begin
        write_component(conn, "</stream:stream>", allow_stopping: true)
        wait_for_component_receiver(done, timeout: 3.0) if done
      rescue ex
        Logger.warn "Error during disconnect: #{ex.message}"
      ensure
        conn.close unless conn.closed?
        if clear_component_connection(conn)
          notify_component_disconnected
        end
      end
    end

    private def wait_for_component_receiver(done : Channel(Nil), timeout : Float64)
      select
      when done.receive
        Logger.debug "Clean disconnect completed"
      when timeout(timeout.seconds)
        Logger.debug "Disconnect timeout reached, forcing close"
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
      conn = @connection_mutex.synchronize { @conn }
      raise NotConnectedError.new("component is not connected") unless conn
      write_component(conn, packet)
    end

    # Loop: Receive data from server
    private def recv(conn : IO, reader : XMLStreamReader, done : Channel(Nil))
      loop do
        begin
          node = reader.read_node
          val = Stanza::Parser.next_packet node, @xmlns

          case val
          when .is_a?(Stanza::StreamError)
            Logger.debug "Stanza::StreamError received"
            Logger.debug val
            @router.route self, val
            packet = val.as(Stanza::StreamError)
            name = packet.error.try &.xml_name.local
            stream_error name || "", packet.text
            conn.close unless conn.closed?
            clear_component_connection(conn)
            return
          end
          @router.route self, val
        rescue ex
          intentional = @connection_mutex.synchronize { @intentional_shutdown }
          unless intentional
            Logger.error ex
            conn.close unless conn.closed?
            notify_component_disconnected(ex) if clear_component_connection(conn)
          end
          return
        end
      end
    ensure
      done.send(nil)
    end

    private def write_component(conn : IO, packet : String, allow_stopping = false)
      @write_mutex.synchronize do
        active, stopping = @connection_mutex.synchronize do
          {@conn.try(&.same?(conn)), @intentional_shutdown}
        end
        unless active && !conn.closed? && (allow_stopping || !stopping)
          raise NotConnectedError.new("component connection is no longer active")
        end
        conn << packet
        conn.flush
      end
    end

    private def ensure_component_connect_not_cancelled
      cancelled = @connection_mutex.synchronize { @connect_cancelled }
      raise ConnectionError.new("component connection attempt was cancelled") if cancelled
    end

    private def clear_component_connection(conn : IO?) : Bool
      @connection_mutex.synchronize do
        next false unless conn && @conn.try(&.same?(conn))
        @conn = nil
        @reader = nil
        @receiver_done = nil
        true
      end
    end

    private def notify_component_disconnected(exception : Exception? = nil)
      notify = @connection_mutex.synchronize do
        next false if @disconnect_notified
        @disconnect_notified = true
        true
      end
      disconnected(SMState.new, exception) if notify
    end

    # XEP-0114: Handle stream errors with specific error types
    private def handle_stream_error(error : Stanza::StreamError)
      error_type = error.error.try &.xml_name.local || "unknown"
      error_text = error.text

      case error_type
      when "conflict"
        # XEP-0114: Component JID is already connected
        raise ComponentConflictError.new(error_text.blank? ? nil : error_text)
      when "host-unknown"
        # XEP-0114: Hostname is not recognized by the server
        raise ComponentHostUnknownError.new(@options.domain)
      when "not-authorized"
        # Authentication failed (wrong secret)
        raise ComponentAuthenticationError.new(error_text.blank? ? "Invalid component secret" : error_text)
      when "invalid-namespace"
        # Invalid namespace in stream
        raise ComponentInvalidNamespaceError.new(error_text.blank? ? nil : error_text)
      else
        # Generic stream error
        raise ComponentStreamError.new(error_type, error_text.blank? ? nil : error_text)
      end
    end

    # hand_shake generates an authentication token based on stream_id and shared secret
    private def hand_shake(stream_id : String)
      # 1. concatenate stream_id received from the server with the shared secret.
      str = stream_id + @options.secret

      # 2. Hash the concatenated string according to the SHA1 algorithm
      Digest::SHA1.hexdigest(str)
    end
  end
end
