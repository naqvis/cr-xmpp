module XMPP::Stanza
  module Parser
    extend self

    # Reads and checks the opening XMPP stream element.
    # Returns a tuple of (stream_id, xmlns) where:
    # - stream_id: The Stream ID is a temporary shared secret used for some hash calculation. It is also used by ProcessOne
    #              reattach features (allowing to resume an existing stream at the point the connection was interrupted, without
    #              getting through the authentication process.
    # - xmlns: The namespace of the stream
    #
    # Note: XEP-0114 stream errors (<conflict/> and <host-unknown/>) are handled in Component class

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
      when NS_SASL2             then decode_sasl2 node
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

    # decode_sasl2 decodes XEP-0388/XEP-0480 SASL2 packets
    def decode_sasl2(node : XML::Node)
      case node.name
      when "authenticate" then SASL2Authenticate.new node
      when "challenge"    then SASL2Challenge.new node
      when "response"     then SASL2Response.new node
      when "continue"     then SASL2Continue.new node
      when "next"         then SASL2Next.new node
      when "task-data"    then SASL2TaskData.new node
      when "success"      then SASL2Success.new node
      else
        raise "unexpected SASL2 packet #{node.namespace.try &.href} <#{node.name}>"
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
