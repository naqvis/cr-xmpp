require "./client"
require "./stanza"

module XMPP
  # DirectInvitation is a high-level client for XEP-0249 - Direct MUC
  # Invitations.
  #
  # A direct invitation is a person-to-person message carrying a
  # Stanza::DirectInvite payload that points the recipient at a room. Send one
  # to a user with the room JID you want them to join.
  #
  #   inviter = XMPP::DirectInvitation.new(client)
  #   inviter.invite("romeo@example.org", "courtyard@chat.example.org",
  #                  reason: "Watching you, Montague")
  #
  # Incoming direct invitations are handled like any other message:
  #
  #   client.on("message") do |s, m|
  #     if invite = m.as(XMPP::Stanza::Message).get(XMPP::Stanza::DirectInvite)
  #       # invite.jid is the room to join
  #     end
  #   end
  #
  # See: https://xmpp.org/extensions/xep-0249.html
  class DirectInvitation
    def initialize(@client : Client)
    end

    # invite sends a direct invitation for the given room (jid) to the
    # recipient (to). Options such as reason, password, and thread are carried
    # as attributes on the invite payload.
    def invite(
      to : String,
      jid : String,
      reason : String? = nil,
      password : String? = nil,
      thread : String? = nil,
      continue : Bool = false,
    )
      invite = Stanza::DirectInvite.new
      invite.jid = jid
      invite.reason = reason.to_s unless reason.nil?
      invite.password = password.to_s unless password.nil?
      invite.thread = thread.to_s unless thread.nil?
      invite.continue = continue

      message = Stanza::Message.new
      message.to = to
      message.extensions << invite
      @client.send message
    end
  end
end
