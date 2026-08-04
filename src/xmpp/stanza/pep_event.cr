require "./registry"
require "./pubsub"

module XMPP::Stanza
  # PubSubEvent is the message payload defined by XEP-0163 - Personal
  # Eventing Protocol. When a user publishes an item on one of their PEP
  # nodes, the server delivers a notification to each subscriber:
  #
  #   <message from='juliet@capulet.lit/balcony' to='romeo@montague.lit/orchard'>
  #     <event xmlns='http://jabber.org/protocol/pubsub#event'>
  #       <items node='http://jabber.org/protocol/tune'>
  #         <item>
  #           <tune xmlns='http://jabber.org/protocol/tune'>
  #             ...
  #           </tune>
  #         </item>
  #       </items>
  #     </event>
  #   </message>
  #
  # It reuses the PubSub Item/Items data models for the notification payload.
  # See: https://xmpp.org/extensions/xep-0163.html
  class PubSubEvent < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/pubsub#event", "event")
    property items : Items? = nil
    property retract : Retract? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "items"   then pr.items = Items.new(child)
        when "retract" then pr.retract = Retract.new(child)
        end
      end
      pr
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
  end

  Registry.map_extension(PacketType::Message, XMLName.new("http://jabber.org/protocol/pubsub#event", "event"), PubSubEvent)
end
