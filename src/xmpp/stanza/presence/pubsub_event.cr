require "../registry"
require "../pubsub"

module XMPP::Stanza
  # PEPEventPres is the presence-carried PEP notification defined by XEP-0223.
  #
  # When a contact is already subscribed to the publisher's presence, the
  # server delivers a PEP notification as a <x xmlns='...pubsub#event'> child
  # of the presence stanza instead of as a separate message. It carries the
  # same items/retract payload as the message-form PubSubEvent.
  class PEPEventPres < PresExtension
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/pubsub#event", "x")
    property items : Items? = nil
    property retract : Retract? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "items"   then cls.items = Items.new(child)
        when "retract" then cls.retract = Retract.new(child)
        end
      end
      cls
    end

    def self.new(xml : String)
      doc = XML.parse(xml)
      root = doc.first_element_child
      if root
        new(root)
      else
        raise "Invalid XML"
      end
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        items.try &.to_xml xml
        retract.try &.to_xml xml
      end
    end

    def name : String
      @@xml_name.local
    end

    # to_event converts the presence form into the shared message-form
    # PubSubEvent model.
    def to_event : PubSubEvent
      event = PubSubEvent.new
      event.items = items
      event.retract = retract
      event
    end
  end

  Registry.map_extension(PacketType::Presence, XMLName.new("http://jabber.org/protocol/pubsub#event", "x"), PEPEventPres)
end
