module XMPP::Stanza
  module Parser
    extend self

    # Reads and checks the opening XMPP stream element.
    # TODO It returns a stream structure containing:
    # - Host: You can check the host against the host you were expecting to connect to
    # - Id: the Stream ID is a temporary shared secret used for some hash calculation. It is also used by ProcessOne
    #       reattach features (allowing to resume an existing stream at the point the connection was interrupted, without
    #       getting through the authentication process.
    # TODO We should handle stream error from XEP-0114 ( <conflict/> or <host-unknown/> )

    def init_stream(node : XML::Node)
      ns = node.namespaces.values.join(",")
      xmlns = node.namespaces["xmlns"]? || ""
      if !node.namespaces.has_value?(NS_STREAM) || node.name != "stream"
        raise "xmpp: expected <stream> but got <#{node.name}> in #{ns}"
      end

      # Parse XMPP stream attributes
      node.attributes.each do |attr|
        case attr.name
        when "id" then return {attr.children[0].content, xmlns}
        end
      end
      {"", xmlns}
    end

    # next_packet scans XML token stream for next complete XMPP stanza.
    # Once the type of stanza has been identified, a structure is created to decode
    # that stanza and returned.
    #
    def next_packet(node : XML::Node, xmlns = NS_CLIENT) : Packet
      # Decode one of the top level XMPP namespace
      ns = node.namespace.try &.href || xmlns
      case ns
      when NS_STREAM            then decode_stream node
      when NS_SASL              then decode_sasl node
      when NS_CLIENT            then decode_client node
      when NS_COMPONENT         then decode_component node
      when NS_STREAM_MANAGEMENT then SMFeatureHandler.parse node
      else
        raise "unknown namespace #{ns} <#{node.name}>"
      end
    end

    # decode_stream will fully decode a stream packet
    def decode_stream(node : XML::Node)
      case node.name
      when "error"    then StreamError.new node
      when "features" then StreamFeatures.new node
      else
        raise "unexpected XMPP packet #{node.namespace.try &.href} <#{node.name}>"
      end
    end

    # decode_sasl decodes a packet related to SASL authentication
    def decode_sasl(node : XML::Node)
      case node.name
      when "challenge" then SASLChallenge.new node
      when "response"  then SASLResponse.new node
      when "success"   then SASLSuccess.new node
      when "failure"   then SASLFailure.new node
      else
        raise "unexpected XMPP packet #{node.namespace.try &.href} <#{node.name}>"
      end
    end

    # decode_client decodes all known packets in the client namespace
    def decode_client(node : XML::Node)
      case node.name
      when "message"  then Message.new node
      when "presence" then Presence.new node
      when "iq"       then IQ.new node
      else
        raise "unexpected XMPP packet #{node.namespace.try &.href} <#{node.name}>"
      end
    end

    # decode_component decodes all known packets in the component namespace
    def decode_component(node : XML::Node)
      case node.name
      when "handshake" then Handshake.new node # handshake is used to authenticate components
      when "message"   then Message.new node
      when "presence"  then Presence.new node
      when "iq"        then IQ.new node
      else
        raise "unexpected XMPP packet #{node.namespace.try &.href} <#{node.name}>"
      end
    end
  end
end
