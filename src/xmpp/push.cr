require "./client"
require "./stanza"

module XMPP
  # Push is a high-level client for XEP-0357 - Push Notifications.
  #
  # A client registers an app server (push service) with its own server so the
  # server can notify the app server when a message arrives for a hibernating
  # or offline session. Support is discovered via disco on the user's bare JID;
  # enable/disable are IQ-sets addressed to the user's bare JID.
  #
  #   push = XMPP::Push.new(client)
  #   return unless push.supported?
  #   push.enable("push-5.client.example", "yxs32uqsflafdk3iuqo")
  #   push.disable("push-5.client.example")
  #
  # See: https://xmpp.org/extensions/xep-0357.html
  class Push
    # Disco feature advertised by servers that support push notifications.
    NS_PUSH = "urn:xmpp:push:0"

    def initialize(@client : Client)
    end

    # supported? queries the server for push support on the client's own bare
    # JID and returns true when the urn:xmpp:push:0 feature is advertised
    # (XEP-0357 §4.1).
    def supported?(timeout : Time::Span = 5.seconds) : Bool
      iq = build_iq("get", Stanza::DiscoInfo.new, to: @client.bare_jid)
      response = @client.request(iq, timeout)
      return false unless response && response.type == "result"
      info = response.payload.as?(Stanza::DiscoInfo)
      return false unless info
      info.features.any? { |feature| feature.var == NS_PUSH }
    end

    # enable registers the given push service (jid) and app-specific node with
    # the server and returns the matching result/error IQ (nil on timeout).
    # Callers check the returned IQ's type == "result".
    def enable(jid : String, node : String, timeout : Time::Span = 5.seconds) : Stanza::IQ?
      payload = Stanza::PushEnable.new
      payload.jid = jid
      payload.node = node
      @client.request(build_iq("set", payload, to: @client.bare_jid), timeout)
    end

    # disable removes the push registration for the given push service (jid),
    # optionally narrowed to a specific node. Returns the result/error IQ (nil
    # on timeout).
    def disable(jid : String, node : String? = nil, timeout : Time::Span = 5.seconds) : Stanza::IQ?
      payload = Stanza::PushDisable.new
      payload.jid = jid
      payload.node = node.to_s unless node.nil?
      @client.request(build_iq("set", payload, to: @client.bare_jid), timeout)
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
