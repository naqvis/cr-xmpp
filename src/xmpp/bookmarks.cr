require "./client"
require "./stanza"
require "./pep"

module XMPP
  # Bookmarks is a high-level client for XEP-0048 - Bookmark Conformance and
  # XEP-0402 - PEP Native Bookmarks.
  #
  # A user's saved chat rooms (and URLs) are published to the well-known PEP
  # node "storage:bookmarks" so all of the user's resources (and authorized
  # contacts) share them. The PEP approach is the modern replacement for
  # storing bookmarks in private XML storage (XEP-0049).
  #
  #   bookmarks = XMPP::Bookmarks.new(client)
  #   mine = XMPP::Stanza::Bookmarks.new
  #   room = XMPP::Stanza::BookmarkConference.new
  #   room.name = "Design"; room.jid = "design@conference.example.org"
  #   room.autojoin = true
  #   mine.conferences << room
  #   bookmarks.publish(mine)
  #
  # Incoming notifications are read from messages like any other extension:
  #
  #   client.on("message") do |s, p|
  #     if bookmarks = XMPP::Bookmarks.from_message(p.as(XMPP::Stanza::Message))
  #       # bookmarks.conferences ...
  #     end
  #   end
  #
  # See: https://xmpp.org/extensions/xep-0048.html and
  #      https://xmpp.org/extensions/xep-0402.html
  class Bookmarks
    # The PEP node used for bookmarks (XEP-0402).
    PEP_NODE = "storage:bookmarks"

    def initialize(@client : Client)
    end

    # publish publishes the bookmarks to the client's own PEP node.
    def publish(bookmarks : Stanza::Bookmarks)
      item = Stanza::Item.new
      item.id = "current"
      item.extra = bookmarks.to_node
      XMPP::PEP.new(@client).publish(PEP_NODE, item)
    end

    # subscribe subscribes the client to another user's bookmarks node.
    def subscribe(jid : String)
      XMPP::PEP.new(@client).subscribe(jid, PEP_NODE)
    end

    # unsubscribe removes the client's subscription to a user's bookmarks node.
    def unsubscribe(jid : String)
      XMPP::PEP.new(@client).unsubscribe(jid, PEP_NODE)
    end

    # from_message extracts the bookmarks from a PEP notification message, or
    # nil when the message does not carry a bookmarks notification.
    def self.from_message(message : Stanza::Message) : Stanza::Bookmarks?
      event = message.get(Stanza::PubSubEvent).as?(Stanza::PubSubEvent)
      return nil unless event
      items = event.items
      return nil unless items && items.node == PEP_NODE
      items.items.each do |item|
        if extra = item.extra
          return Stanza::Bookmarks.from_node(extra)
        end
      end
      nil
    end
  end
end
