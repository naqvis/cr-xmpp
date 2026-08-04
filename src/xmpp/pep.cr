require "./client"
require "./stanza"

module XMPP
  # PEP is a high-level client for XEP-0163 - Personal Eventing Protocol.
  #
  # PEP lets a user publish items on their own pubsub nodes and subscribe to
  # the nodes of other contacts. The server advertises PEP support with the
  # disco feature "http://jabber.org/protocol/pubsub#pep".
  #
  # Incoming notifications arrive as Message stanzas carrying a
  # Stanza::PubSubEvent payload and are handled like any other message:
  #
  #   client.on("message") do |s, p|
  #     if event = p.as(XMPP::Stanza::Message).get(XMPP::Stanza::PubSubEvent)
  #       # event.items.node, event.items.items ...
  #     end
  #   end
  #
  # See: https://xmpp.org/extensions/xep-0163.html
  class PEP
    # Disco feature advertised by servers that support PEP.
    NS_PEP = "http://jabber.org/protocol/pubsub#pep"

    def initialize(@client : Client)
    end

    # publish sends an item to one of the client's own nodes. The item
    # payload is a Stanza::Item (typically carrying a Tune or Mood).
    def publish(node : String, item : Stanza::Item)
      pubsub = Stanza::PubSub.new
      publish = Stanza::Publish.new
      publish.node = node
      publish.item = item
      pubsub.publish = publish
      @client.send build_iq("set", pubsub, to: nil)
    end

    # subscribe subscribes the client to a node owned by the given bare JID.
    def subscribe(jid : String, node : String)
      pubsub = Stanza::PubSub.new
      subscribe = Stanza::Subscribe.new
      subscribe.node = node
      subscribe.jid = @client.bare_jid
      pubsub.subscribe = subscribe
      @client.send build_iq("set", pubsub, to: jid)
    end

    # unsubscribe removes the client's subscription to a node owned by the
    # given bare JID.
    def unsubscribe(jid : String, node : String)
      pubsub = Stanza::PubSub.new
      unsubscribe = Stanza::Unsubscribe.new
      unsubscribe.node = node
      unsubscribe.jid = @client.bare_jid
      pubsub.unsubscribe = unsubscribe
      @client.send build_iq("set", pubsub, to: jid)
    end

    # supported? queries the server for PEP support on the client's own bare
    # JID and returns true when PEP is advertised. Per XEP-0163 §4.1 a PEP
    # server advertises the disco identity pubsub/pep; the
    # http://jabber.org/protocol/pubsub#pep feature is a common extra signal.
    def supported?(timeout : Time::Span = 5.seconds) : Bool
      iq = build_iq("get", Stanza::DiscoInfo.new, to: @client.bare_jid)
      response = @client.request(iq, timeout)
      return false unless response && response.type == "result"
      info = response.payload.as?(Stanza::DiscoInfo)
      return false unless info
      info.identity.any? { |identity| identity.category == "pubsub" && identity.type == "pep" } ||
        info.features.any? { |feature| feature.var == NS_PEP }
    end

    private def build_iq(type : String, payload : Stanza::IQPayload, to : String?)
      iq = Stanza::IQ.new
      iq.type = type
      iq.to = to unless to.nil?
      iq.payload = payload
      iq
    end
  end
end
