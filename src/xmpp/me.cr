require "./stanza"

module XMPP
  # Me provides helpers for XEP-0245 - The /me Command.
  #
  # XEP-0245 is a purely client-side convention: a message whose body begins
  # with the exact string "/me " indicates that the sender is performing a
  # third-person action. A conforming client sends such a body verbatim and,
  # when displaying one received from another user, replaces the "/me " prefix
  # with the sender's identity (nickname, local part, etc.) preceded by an
  # asterisk.
  #
  #   body = XMPP::Me.body("dances a jig")   # => "/me dances a jig"
  #   text = XMPP::Me.display("Juliet", body) # => "* Juliet dances a jig"
  #
  # See: https://xmpp.org/extensions/xep-0245.html
  module Me
    # The literal prefix that marks a body as a /me command.
    PREFIX = "/me "

    # body wraps the given text in the /me prefix for sending.
    def self.body(text : String) : String
      "#{PREFIX}#{text}"
    end

    # display renders a /me command for presentation, replacing the prefix
    # with the speaker's identity. If the text does not start with the /me
    # prefix it is returned unchanged.
    def self.display(identity : String, text : String) : String
      return text unless text.starts_with?(PREFIX)
      "* #{identity} #{text.lchop(PREFIX)}"
    end
  end
end
