require "./client"
require "./stanza"

module XMPP
  # MessageArchives is a high-level client for XEP-0313 - Message Archive
  # Management.
  #
  # MAM lets a client query the server for its archived messages, optionally
  # filtered by chat partner and time range and paged with RSM. The IQ returns
  # a MAMFin; each archived message is then streamed as a normal Message
  # stanza carrying a Stanza::MAMResult payload, which is handled like any
  # other message:
  #
  #   archives = XMPP::MessageArchives.new(client)
  #   return unless archives.supported?
  #   fin = archives.query(with: "juliet@capulet.lit", limit: 10)
  #   fin.try(&.complete)  # true when all results were streamed
  #
  #   client.on("message") do |s, m|
  #     if result = m.as(XMPP::Stanza::Message).get(XMPP::Stanza::MAMResult)
  #       archived = result.as(XMPP::Stanza::MAMResult).forwarded.try(&.stanza)
  #     end
  #   end
  #
  # See: https://xmpp.org/extensions/xep-0313.html
  class MessageArchives
    # Disco feature advertised by servers that support MAM.
    NS_MAM = "urn:xmpp:mam:2"

    def initialize(@client : Client)
    end

    # supported? queries the server for MAM support and returns true when the
    # urn:xmpp:mam:2 feature is advertised on the given JID (defaults to the
    # user's bare JID).
    def supported?(jid : String? = nil, timeout : Time::Span = 5.seconds) : Bool
      target = jid || @client.bare_jid
      iq = build_iq("get", Stanza::DiscoInfo.new, target)
      response = @client.request(iq, timeout)
      return false unless response && response.type == "result"
      info = response.payload.as?(Stanza::DiscoInfo)
      return false unless info
      info.features.any? { |feature| feature.var == NS_MAM }
    end

    # query requests archived messages and returns the MAMFin IQ payload (nil
    # on error or timeout). The archived messages themselves arrive as Message
    # stanzas carrying Stanza::MAMResult and are delivered to the client's
    # normal message handling. Filters: with restricts to a chat partner;
    # since/until bound the time range; limit and after page the result set.
    def query(
      with_jid : String? = nil,
      since : Time? = nil,
      until_time : Time? = nil,
      limit : Int32 = 0,
      after : String? = nil,
      queryid : String = Random::Secure.hex(8),
      timeout : Time::Span = 5.seconds,
    ) : Stanza::MAMFin?
      req = Stanza::MAMQuery.new
      req.queryid = queryid
      req.with_jid = with_jid.to_s unless with_jid.nil?
      req.start = since unless since.nil?
      req.finish = until_time unless until_time.nil?
      req.max = limit
      req.after = after.to_s unless after.nil?

      response = @client.request(build_iq("set", req, @client.bare_jid), timeout)
      return nil unless response && response.type == "result"
      response.payload.as?(Stanza::MAMFin)
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
