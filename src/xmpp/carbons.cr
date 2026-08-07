require "./client"
require "./stanza"

module XMPP
  # Carbons is a high-level client for XEP-0280 - Message Carbons.
  #
  # When enabled, the server carbon-copies the user's chat messages to all of
  # the user's connected resources, wrapping each copy in a <sent/> or
  # <received/> payload that forwards the original stanza. Enable the feature
  # after the initial presence so the server knows the resource is online.
  #
  #   carbons = XMPP::Carbons.new(client)
  #   carbons.enable  # after initial presence
  #   ...
  #   carbons.disable
  #
  # Incoming carbon copies arrive as message extensions:
  #
  #   client.on("message") do |s, m|
  #     message = m.as(XMPP::Stanza::Message)
  #     if sent = message.get(XMPP::Stanza::CarbonSent)
  #       original = sent.forwarded.try(&.stanza)
  #     end
  #   end
  #
  # See: https://xmpp.org/extensions/xep-0280.html
  class Carbons
    # Disco feature advertised by servers that support message carbons.
    NS_CARBONS = "urn:xmpp:carbons:2"

    def initialize(@client : Client)
    end

    # supported? queries the server for carbon support and returns true when
    # the urn:xmpp:carbons:2 feature is advertised (XEP-0280 §3.1). The
    # feature is advertised on the server domain rather than the user's bare
    # JID.
    def supported?(timeout : Time::Span = 5.seconds) : Bool
      domain = XMPP::JID.new(@client.bare_jid).domain
      iq = build_iq("get", Stanza::DiscoInfo.new, domain)
      response = @client.request(iq, timeout)
      return false unless response && response.type == "result"
      info = response.payload.as?(Stanza::DiscoInfo)
      return false unless info
      info.features.any? { |feature| feature.var == NS_CARBONS }
    end

    # enable turns on carbon copies for the client's resource. Per XEP-0280
    # §3.2 this should be done after the initial presence. Returns the
    # result/error IQ (nil on timeout).
    def enable(timeout : Time::Span = 5.seconds) : Stanza::IQ?
      @client.request(build_iq("set", Stanza::CarbonsEnable.new, @client.bare_jid), timeout)
    end

    # disable turns off carbon copies for the client's resource. Returns the
    # result/error IQ (nil on timeout).
    def disable(timeout : Time::Span = 5.seconds) : Stanza::IQ?
      @client.request(build_iq("set", Stanza::CarbonsDisable.new, @client.bare_jid), timeout)
    end

    private def build_iq(type : String, payload : Stanza::IQPayload, to : String)
      iq = Stanza::IQ.new
      iq.type = type
      iq.to = to
      iq.payload = payload
      iq
    end
  end
end
