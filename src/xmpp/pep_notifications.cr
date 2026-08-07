require "./client"
require "./stanza"

module XMPP
  # PEPNotifications is a high-level client for XEP-0223 - PEP Notifications.
  #
  # PEP notifications carry an event payload on a subscribed node. When the
  # subscriber also subscribes to the publisher's presence, the notification
  # is delivered inside the presence stanza (as a
  # <x xmlns='...pubsub#event'> extension); otherwise it arrives as a message
  # carrying Stanza::PubSubEvent. This wrapper normalizes both delivery
  # channels into the shared PubSubEvent model.
  #
  #   client.on("message") do |s, p|
  #     event = XMPP::PEPNotifications.from_message(p.as(XMPP::Stanza::Message))
  #   end
  #
  #   client.on("presence") do |s, p|
  #     event = XMPP::PEPNotifications.from_presence(p.as(XMPP::Stanza::Presence))
  #   end
  #
  # See: https://xmpp.org/extensions/xep-0223.html
  class PEPNotifications
    # from_message extracts the pubsub#event payload from a message, or nil.
    def self.from_message(message : Stanza::Message) : Stanza::PubSubEvent?
      message.get(Stanza::PubSubEvent).as?(Stanza::PubSubEvent)
    end

    # from_presence extracts the pubsub#event payload carried by a presence
    # stanza (XEP-0223 §5), or nil.
    def self.from_presence(presence : Stanza::Presence) : Stanza::PubSubEvent?
      extension = presence.get(Stanza::PEPEventPres).as?(Stanza::PEPEventPres)
      extension.try(&.to_event)
    end

    # from_stanza accepts either a message or presence stanza and returns its
    # pubsub#event payload, or nil when neither carries one.
    def self.from_stanza(stanza) : Stanza::PubSubEvent?
      case stanza
      when Stanza::Message  then from_message(stanza)
      when Stanza::Presence then from_presence(stanza)
      end
    end
  end
end
