require "../registry"
require "../../xmpp"

module XMPP::Stanza
  NS_MESSAGE_CORRECT = "urn:xmpp:message-correct:0"

  # Replace implements XEP-0308 - Last Message Correction.
  #
  # A corrected message is a regular chat message whose <replace/> payload
  # carries the id of the message it corrects. The corrected <body/> supersedes
  # the original one.
  class Replace < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(NS_MESSAGE_CORRECT, "replace")
    property id : String = ""

    def self.new(xml : String)
      doc = XML.parse(xml)
      root = doc.first_element_child
      if root
        new(root)
      else
        raise "Invalid XML"
      end
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      cls.id = node["id"]? || ""
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space, id: id)
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new(NS_MESSAGE_CORRECT, "replace"), Replace)
end
