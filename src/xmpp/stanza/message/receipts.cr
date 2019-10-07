require "../registry"
require "../../xmpp"

module XMPP::Stanza
  MSG_RECEIPTS_NS = "urn:xmpp:receipts"

  # Support for:
  # - XEP-0184 - Message Delivery Receipts: https://xmpp.org/extensions/xep-0184.html

  # Used on outgoing message, to tell the recipient that you are requesting a message receipt / ack.
  class ReceiptRequest < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_RECEIPTS_NS, "request")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      @@xml_name.local
    end
  end

  class ReceiptReceived < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_RECEIPTS_NS, "received")
    property id : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "id" then pr.id = attr.children[0].content
        end
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["id"] = id unless id.blank?
      elem.element(@@xml_name.local, dict)
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new(MSG_RECEIPTS_NS, "request"), ReceiptRequest)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_RECEIPTS_NS, "received"), ReceiptReceived)
end
