require "../registry"
require "../../xmpp"

module XMPP::Stanza
  MSG_CHAT_MARKERS_NS = "urn:xmpp:chat-markers:0"

  # Support for:
  # - XEP-0333 - Chat Markers: https://xmpp.org/extensions/xep-0333.html
  class Markable < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:chat-markers:0", "markable")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name
      @@xml_name.local
    end
  end

  class MarkReceived < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:chat-markers:0", "received")
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

  class MarkDisplayed < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:chat-markers:0", "displayed")
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

  class MarkAcknowledged < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:chat-markers:0", "acknowledged")
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

  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_MARKERS_NS, "markable"), Markable)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_MARKERS_NS, "received"), MarkReceived)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_MARKERS_NS, "displayed"), MarkDisplayed)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_MARKERS_NS, "acknowledged"), MarkAcknowledged)
end
