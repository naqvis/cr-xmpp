require "./client"
require "./stanza"

module XMPP
  # VCard is a high-level client for XEP-0054 - vcard-temp.
  #
  # vcard-temp is a legacy form of structured user data (name, address, photo)
  # exchanged as an IQ get/set against a user's bare JID. Servers that support
  # it do not advertise a disco feature; support is instead determined by
  # whether the vcard-temp IQ succeeds.
  #
  #   vc = XMPP::VCard.new(client)
  #   card = vc.fetch  # => Stanza::VCard? for the current user
  #   card.fn = "Juliet Capulet"
  #   card.set(card)
  #
  # See: https://xmpp.org/extensions/xep-0054.html
  class VCard
    # Disco feature is not used by vcard-temp, but is exposed for symmetry.
    NS_VCARD_TEMP = "vcard-temp"

    def initialize(@client : Client)
    end

    # fetch retrieves the vCard stored for the given bare JID (defaults to the
    # current user). Returns the Stanza::VCard payload on a successful result,
    # or nil on error or timeout.
    def fetch(jid : String? = nil, timeout : Time::Span = 5.seconds) : Stanza::VCard?
      iq = build_iq("get", Stanza::VCard.new, jid || @client.bare_jid)
      response = @client.request(iq, timeout)
      return nil unless response && response.type == "result"
      response.payload.as?(Stanza::VCard)
    end

    # set stores the given vCard against the current user. Returns the
    # result/error IQ (nil on timeout); callers check type == "result".
    def set(vcard : Stanza::VCard, timeout : Time::Span = 5.seconds) : Stanza::IQ?
      @client.request(build_iq("set", vcard, @client.bare_jid), timeout)
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
