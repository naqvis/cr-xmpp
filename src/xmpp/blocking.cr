require "./client"
require "./stanza"

module XMPP
  # Blocking is a high-level client for XEP-0191 - Blocking Command.
  #
  # Blocking lets a client prevent inbound communication from selected JIDs
  # (or their bare-JID domains) by managing a server-side blocklist.
  #
  #   blocking = XMPP::Blocking.new(client)
  #   return unless blocking.supported?
  #   blocking.block("spammer@example.org")
  #   blocking.list         # => [BlockItem(jid: "spammer@example.org")]
  #   blocking.unblock("spammer@example.org")
  #
  # See: https://xmpp.org/extensions/xep-0191.html
  class Blocking
    # Disco feature advertised by servers that support blocking.
    NS_BLOCKING = "urn:xmpp:blocking"

    def initialize(@client : Client)
    end

    # supported? queries the server for blocking support and returns true when
    # the urn:xmpp:blocking feature is advertised.
    def supported?(timeout : Time::Span = 5.seconds) : Bool
      iq = build_iq("get", Stanza::DiscoInfo.new, @client.bare_jid)
      response = @client.request(iq, timeout)
      return false unless response && response.type == "result"
      info = response.payload.as?(Stanza::DiscoInfo)
      return false unless info
      info.features.any? { |feature| feature.var == NS_BLOCKING }
    end

    # list returns the JIDs currently blocked (as BlockItem), or nil on error.
    def list(timeout : Time::Span = 5.seconds) : Array(Stanza::BlockItem)?
      response = @client.request(build_iq("get", Stanza::Blocklist.new, @client.bare_jid), timeout)
      return nil unless response && response.type == "result"
      payload = response.payload.as?(Stanza::Blocklist)
      payload.try(&.items)
    end

    # block blocks the given jids. Returns the result/error IQ (nil on timeout).
    def block(jids : Enumerable(String), timeout : Time::Span = 5.seconds) : Stanza::IQ?
      block = Stanza::Block.new
      jids.each { |jid| block.items << Stanza::BlockItem.new(jid) }
      @client.request(build_iq("set", block, @client.bare_jid), timeout)
    end

    # block is a convenience overload for a single JID.
    def block(jid : String, timeout : Time::Span = 5.seconds) : Stanza::IQ?
      block([jid], timeout)
    end

    # unblock unblocks the given jids. Returns the result/error IQ. When no
    # jids are given the whole blocklist is cleared.
    def unblock(jids : Enumerable(String)? = nil, timeout : Time::Span = 5.seconds) : Stanza::IQ?
      unblock = Stanza::Unblock.new
      jids.try &.each { |jid| unblock.items << Stanza::BlockItem.new(jid) }
      @client.request(build_iq("set", unblock, @client.bare_jid), timeout)
    end

    # unblock is a convenience overload for a single JID.
    def unblock(jid : String, timeout : Time::Span = 5.seconds) : Stanza::IQ?
      unblock([jid], timeout)
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
