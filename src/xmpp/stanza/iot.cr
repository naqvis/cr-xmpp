require "./registry"
require "../stanza"

module XMPP::Stanza
  class ControlSet < MsgExtension
    include IQPayload

    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:iot:control", "set")
    property lang : String = ""

    property fields : Array(ControlField) = Array(ControlField).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "lang" then pr.lang = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        pr.fields << ControlField.new(child)
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["xml:lang"] = lang unless lang.blank?
      dict["xmlns"] = @@xml_name.space
      elem.element(@@xml_name.local, dict) do
        fields.each { |f| f.to_xml elem }
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  class ControlField < MsgExtension
    property xml_name : String = ""
    property name : String = ""
    property value : String = ""

    def self.new(node : XML::Node)
      pr = new()
      pr.xml_name = node.name
      node.attributes.each do |attr|
        case attr.name
        when "name"  then pr.name = attr.children[0].content
        when "value" then pr.value = attr.children[0].content
        end
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["name"] = name unless name.blank?
      dict["value"] = value unless value.blank?

      elem.element(xml_name, dict)
    end
  end

  class ControlGetForm < MsgExtension
    include IQPayload

    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:iot:control", "getForm")
    property any : XML::Node? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        pr.any = child
        break
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        any unless any.nil?
      end
    end

    def name : String
      @@xml_name.local
    end

    def namespace : String
      @@xml_name.space
    end
  end

  class ControlSetResponse < MsgExtension
    include IQPayload

    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:iot:control", "setResponse")
    property any : XML::Node? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        pr.any = child
        break
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        any unless any.nil?
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new("urn:xmpp:iot:control", "set"), ControlSet)
end
