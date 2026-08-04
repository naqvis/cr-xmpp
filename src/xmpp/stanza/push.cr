require "./registry"
require "./node"
require "../stanza"

module XMPP::Stanza
  # XEP-0357: Push Notifications - https://xmpp.org/extensions/xep-0357.html
  NS_PUSH = "urn:xmpp:push:0"

  class PushEnable < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_PUSH, "enable")
    property jid : String = ""
    property node : String = ""
    getter any : Array(Node) = Array(Node).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "jid"  then pr.jid = attr.children[0].content
        when "node" then pr.node = attr.children[0].content
        else
          # ignored
        end
      end
      node.children.select(&.element?).each do |child|
        pr.any << Node.new(child)
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["jid"] = jid unless jid.blank?
      dict["node"] = node unless node.blank?
      xml.element(@@xml_name.local, dict) do
        any.each(&.to_xml(xml))
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  class PushDisable < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_PUSH, "disable")
    property jid : String = ""
    property node : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "jid"  then pr.jid = attr.children[0].content
        when "node" then pr.node = attr.children[0].content
        else
          # ignored
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["jid"] = jid unless jid.blank?
      dict["node"] = node unless node.blank?
      xml.element(@@xml_name.local, dict)
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_PUSH, "enable"), PushEnable)
  Registry.map_extension(PacketType::IQ, XMLName.new(NS_PUSH, "disable"), PushDisable)
end
