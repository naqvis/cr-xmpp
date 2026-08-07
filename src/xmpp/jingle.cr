require "./client"
require "./stanza"

module XMPP
  # Jingle is a high-level helper for XEP-0166 Jingle sessions used by the
  # file-transfer (XEP-0234) and in-band bytestream (XEP-0261) application
  # descriptions. It builds and parses session-initiate / session-accept
  # stanzas for a single content offer.
  #
  #   jingle = XMPP::Jingle.new(client)
  #   offer = jingle.build_offer("peer@example.org", "abc-123",
  #                              name: "report.pdf", size: 2048_i64)
  #   jingle.send_offer(offer)
  #
  # See: https://xmpp.org/extensions/xep-0166.html
  #      https://xmpp.org/extensions/xep-0234.html
  #      https://xmpp.org/extensions/xep-0261.html
  class Jingle
    # Session actions from XEP-0166.
    module Action
      SESSION_INITIATE  = "session-initiate"
      SESSION_ACCEPT    = "session-accept"
      SESSION_TERMINATE = "session-terminate"
    end

    def initialize(@client : Client)
    end

    # build_offer builds a session-initiate IQ offering a single file-transfer
    # content. When ibb_block_size is greater than zero an In-Band Bytestream
    # description is added alongside, negotiating a stream over XEP-0047.
    def build_offer(to : JID | String, sid : String, name : String,
                    size : Int64 = 0_i64, ibb_block_size : Int32 = 0,
                    initiator_domain : String? = nil) : Stanza::IQ
      initiator = initiator_domain || @client.bare_jid
      ft = Stanza::JingleFileTransfer.new
      ft.offer = true
      file = Stanza::JingleFile.new
      file.name = name
      file.size = size
      ft.file = file

      content = Stanza::Content.new
      content.creator = "initiator"
      content.name = "a-file-offer"
      content.description = ft

      jing = Stanza::Jingle.new
      jing.action = Action::SESSION_INITIATE
      jing.initiator = initiator
      jing.sid = sid
      jing.contents << content
      if ibb_block_size > 0
        ibb = Stanza::JingleIBB.new
        ibb.block_size = ibb_block_size
        ibb_content = Stanza::Content.new
        ibb_content.creator = "initiator"
        ibb_content.name = "in-band-ibb"
        ibb_content.description = ibb
        jing.contents << ibb_content
      end

      iq = Stanza::IQ.new
      iq.to = to.to_s
      iq.type = "set"
      iq.payload = jing
      iq
    end

    # build_accept builds a session-accept IQ acknowledging a received offer.
    def build_accept(to : JID | String, initiator : String, sid : String) : Stanza::IQ
      content = Stanza::Content.new
      content.creator = "responder"
      content.name = "a-file-offer"

      jingle = Stanza::Jingle.new
      jingle.action = Action::SESSION_ACCEPT
      jingle.responder = @client.bare_jid
      jingle.sid = sid
      jingle.contents << content

      iq = Stanza::IQ.new
      iq.to = to.to_s
      iq.type = "set"
      iq.payload = jingle
      iq
    end

    # build_terminate builds a session-terminate IQ to end a session.
    def build_terminate(to : JID | String, sid : String) : Stanza::IQ
      jingle = Stanza::Jingle.new
      jingle.action = Action::SESSION_TERMINATE
      jingle.sid = sid

      iq = Stanza::IQ.new
      iq.to = to.to_s
      iq.type = "set"
      iq.payload = jingle
      iq
    end

    # send_offer sends a session-initiate IQ and returns the negotiated
    # content descriptions carried in the response, if any.
    def send_offer(iq : Stanza::IQ, timeout : Time::Span = 5.seconds)
      response = @client.request(iq, timeout)
      parse(response)
    end

    # parse extracts a Jingle stanza from an IQ response payload.
    def parse(iq : Stanza::IQ?) : Stanza::Jingle?
      return nil unless iq
      iq.payload.as?(Stanza::Jingle)
    end
  end
end
