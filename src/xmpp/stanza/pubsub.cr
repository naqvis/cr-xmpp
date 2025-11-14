require "./pep"
require "./registry"

module XMPP::Stanza
  # # PubSub Stanza
  #
  # [XEP-0060 - Publish-Subscribe](http://xmpp.org/extensions/xep-0060.html)

  class PubSub < MsgExtension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/pubsub", "pubsub")
    property publish : Publish? = nil
    property retract : Retract? = nil

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
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "publish" then pr.publish = Publish.new(child)
        when "retract" then pr.retract = Retract.new(child)
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        publish.try &.to_xml xml
        retract.try &.to_xml xml
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  class Publish
    class_getter xml_name : String = "publish"
    property node : String = ""
    property item : Item? = nil

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name

      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node" then pr.node = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      node.children.select(&.element?).each do |child|
        pr.item = Item.new(child)
        break
      end
      pr
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?

      xml.element(@@xml_name, dict) do
        item.try &.to_xml xml
      end
    end
  end

  class Item
    class_getter xml_name : String = "item"
    property id : String = ""
    property tune : Tune? = nil
    property mood : Mood? = nil

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "id" then pr.id = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "tune" then pr.tune = Tune.new(child)
        when "mood" then pr.mood = Mood.new(child)
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      pr
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["id"] = id unless id.blank?

      xml.element(@@xml_name, dict) do
        tune.try &.to_xml xml
        mood.try &.to_xml xml
      end
    end
  end

  class Retract
    class_getter xml_name : String = "retract"
    property node : String = ""
    property notify : String = ""
    property item : Item? = nil

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node"   then pr.node = attr.children[0].content
        when "notify" then pr.notify = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      node.children.select(&.element?).each do |child|
        pr.item = Item.new(child)
        break
      end
      pr
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      dict["notify"] = notify unless notify.blank?

      xml.element(@@xml_name, dict) do
        item.try &.to_xml xml
      end
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new("http://jabber.org/protocol/pubsub", "pubsub"), PubSub)
end
