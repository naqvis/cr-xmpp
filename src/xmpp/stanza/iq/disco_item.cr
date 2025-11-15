require "../registry"
require "../../xmpp"

module XMPP::Stanza
  NS_DISCO_ITEMS = "http://jabber.org/protocol/disco#items"

  # XEP-0030: Service Discovery http://www.xmpp.org/extensions/xep-0030.html
  class DiscoItems < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_DISCO_ITEMS, "query")
    property node : String = ""
    property items : Array(DiscoItem) = Array(DiscoItem).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "node" then cls.node = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "item" then cls.items << DiscoItem.new(child)
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space unless @@xml_name.space.blank?
      dict["node"] = node unless node.blank?

      xml.element(@@xml_name.local, dict) do
        items.each do |v|
          v.to_xml xml
        end
      end
    end

    def add_item(jid : String, node : String, name : String)
      item = DiscoItem.new
      item.jid = jid
      item.node = node
      item.name = name

      @items << item
      self
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  class DiscoItem
    class_getter xml_name : String = "item"
    property jid : String = ""
    property node : String = ""
    property name : String = ""

    def initialize(@jid = "", @node = "", @name = "")
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "jid"  then cls.jid = attr.children[0].content
        when "node" then cls.node = attr.children[0].content
        when "name" then cls.name = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new

      dict["jid"] = jid unless jid.blank?
      dict["node"] = node unless node.blank?
      dict["name"] = name unless name.blank?

      xml.element(@@xml_name, dict)
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_DISCO_ITEMS, "query"), DiscoItems)
end
