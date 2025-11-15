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

    # Communication with developer client / StreamManager

    def initialize(@domain, @secret, @host, @port, @name, @category, @type, @log_file = nil)
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
    # TCP level connection
    @conn : IO?
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
      socket = TCPSocket.new(@options.host, @options.port, connect_timeout: 5)
      @conn = StreamLogger.new(socket, @options.log_file)

      xml = sprintf COMP_STREAM_OPEN, @options.domain, Stanza::NS_COMPONENT, Stanza::NS_STREAM
      # 1. Send stream open tag
      send xml
      # 2. extract stream_id
      stream_id, @xmlns = Stanza::Parser.init_stream(read_resp)
      raise "Unable to retrieve stream id" if stream_id.blank?

      # 3. Authentication
      xml = sprintf "<handshake>%s</handshake>", hand_shake stream_id
      send xml

      # 4. Check server response for authentication
      val = Stanza::Parser.next_packet read_resp, @xmlns

      case val
      when .is_a?(Stanza::StreamError)
        v = val.as(Stanza::StreamError)
        handle_stream_error(v)
      when .is_a?(Stanza::Handshake)
        # start the receiver fiber
        spawn do
          recv
        end
      else
        raise ComponentError.new("expecting handshake result, got : #{val.name}")
      end
    end

    def resume(state : SMState)
      # components do not support stream management, so just call connect instead
      connect
    end

    def disconnect
      return unless conn = @conn
      return if conn.closed?

      begin
        # Send closing stream tag
        send("</stream:stream>")

        # Wait for server's closing stream tag (with timeout)
        # RFC 6120: The receiving entity should respond with a closing stream tag
        wait_for_stream_close(conn, timeout: 3.0)
      rescue ex
        Logger.warn "Error during disconnect: #{ex.message}"
      ensure
        conn.close unless conn.closed?
        update_state ConnectionState::Disconnected
      end
    end

    # Wait for the server to send its closing stream tag
    private def wait_for_stream_close(conn : IO, timeout : Float64)
      done = Channel(Bool).new

      spawn do
        begin
          # Try to read the closing stream tag from server
          b = Bytes.new(1024)
          n = conn.read(b)
          if n > 0
            xml = String.new(b[0, n])
            # Check if we received a closing stream tag
            if xml.includes?("</stream:stream>")
              Logger.debug "Received closing stream tag from server"
            end
          end
        rescue ex
          Logger.debug "Stream close read error (expected): #{ex.message}"
        ensure
          done.send(true)
        end
      end

      # Wait for either completion or timeout
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
      if (socket = @conn) && !socket.closed?
        socket << packet
        socket.flush
      else
        raise "Component is not connected"
      end
    end

    # Loop: Receive data from server
    private def recv
      loop do
        begin
          node = read_resp
          val = Stanza::Parser.next_packet node, @xmlns
        rescue ex
          update_state ConnectionState::Disconnected
          Logger.error ex
          raise ex
        end
        # Handle stream errors
        case val
        when .is_a?(Stanza::StreamError)
          Logger.debug "Stanza::StreamError received"
          Logger.debug val
          @router.route self, val
          packet = val.as(Stanza::StreamError)
          name = packet.error.try &.xml_name.local
          stream_error name || "", packet.text
          raise "stream error: #{name}"
        end
        @router.route self, val
      end
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

    private def read_resp
      if socket = @conn
        b = Bytes.new(1024)
        n = socket.read(b)
        raise ConnectionClosed.new "connection closed" if socket.closed? || n == 0
        xml = String.new(b[0, n])
        document = XML.parse(xml)
        if r = document.first_element_child
          r
        else
          raise "Invalid response from server: #{document.to_xml}"
        end
      else
        raise "Component is not connected"
      end
    end
  end
end
