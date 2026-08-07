require "../registry"
require "../../xmpp"

module XMPP::Stanza
  NS_BLOCKING = "urn:xmpp:blocking"

  # BlockItem is one entry (an <item jid='...'/>) in a blocklist or a
  # block/unblock command, per XEP-0191.
  class BlockItem
    class_getter xml_name : String = "item"
    property jid : String = ""

    def initialize(@jid : String = "")
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      new(node["jid"]? || "")
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name, jid: jid)
    end
  end

  # Blocklist is the <blocklist/> payload returned by a get request, listing
  # every currently blocked JID.
  class Blocklist < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_BLOCKING, "blocklist")
    getter items : Array(BlockItem) = Array(BlockItem).new

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
      node.children.select(&.element?).each do |child|
        cls.items << BlockItem.new(child) if child.name == BlockItem.xml_name
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        items.each &.to_xml xml
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # Block is a set command blocking the listed JIDs.
  class Block < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_BLOCKING, "block")
    getter items : Array(BlockItem) = Array(BlockItem).new

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
      node.children.select(&.element?).each do |child|
        cls.items << BlockItem.new(child) if child.name == BlockItem.xml_name
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        items.each &.to_xml xml
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # Unblock is a set command unblocking the listed JIDs, or all of them when no
  # items are present.
  class Unblock < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_BLOCKING, "unblock")
    getter items : Array(BlockItem) = Array(BlockItem).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        cls.items << BlockItem.new(child) if child.name == BlockItem.xml_name
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        items.each &.to_xml xml
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_BLOCKING, "blocklist"), Blocklist)
  Registry.map_extension(PacketType::IQ, XMLName.new(NS_BLOCKING, "block"), Block)
  Registry.map_extension(PacketType::IQ, XMLName.new(NS_BLOCKING, "unblock"), Unblock)
end
