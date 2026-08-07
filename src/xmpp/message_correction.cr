require "./client"
require "./stanza"

module XMPP
  # MessageCorrection is a high-level client for XEP-0308 - Last Message
  # Correction.
  #
  # A corrected chat message replaces an earlier one by referencing its id.
  # Receivers with support treat the new body as authoritative.
  #
  #   corrector = XMPP::MessageCorrection.new(client)
  #   corrector.correct(to: "juliet@capulet.lit", original_id: id, body: "My pardon")
  #
  # Incoming corrections are handled like any other message:
  #
  #   client.on("message") do |s, m|
  #     if replace = m.as(XMPP::Stanza::Message).get(XMPP::Stanza::Replace)
  #       replace.id  # the id of the message being corrected
  #     end
  #   end
  #
  # See: https://xmpp.org/extensions/xep-0308.html
  class MessageCorrection
    def initialize(@client : Client)
    end

    # correct sends a corrected message whose body supersedes the message
    # identified by original_id.
    def correct(to : String, original_id : String, body : String, type : String = "chat")
      replace = Stanza::Replace.new
      replace.id = original_id

      message = Stanza::Message.new
      message.type = type
      message.to = to
      message.body = body
      message.extensions << replace
      @client.send message
    end

    # corrected? returns the id of the message this message corrects, or nil
    # when it is not a correction.
    def corrected?(message : Stanza::Message) : String?
      replace = message.get(Stanza::Replace).as?(Stanza::Replace)
      return nil unless replace
      replace.id.blank? ? nil : replace.id
    end
  end
end
