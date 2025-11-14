require "./event_manager"
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

    getter options : ComponentOptions
    @router : Router
    # TCP level connection
    @conn : IO?

    def initialize(@options, @router)
      @xmlns = ""
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
        raise "handshake failed : #{v.error.try &.xml_name.local}"
      when .is_a?(Stanza::Handshake)
        # start the receiver fiber
        spawn do
          recv
        end
      else
        raise "expecting handshake result, got : #{val.name}"
      end
    end

    def resume(state : SMState)
      # components do not support stream management, so just call connect instead
      connect
    end

    def disconnect
      send("</stream:stream>")
      # TODO: Add a way to wait for stream close acknowledgement from the server for clean disconnect
      @conn.try &.close
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

    # TODO: Add support for discovery management directly in component
    # TODO: Support multiple identities on disco info
    # TODO: Support returning features on disco info

  end
end
