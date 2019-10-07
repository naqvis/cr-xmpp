require "../stanza"
require "./packet"
require "./registry"
require "./forwarded"

module XMPP::Stanza
  # Handshake Stanza
  # Handshake is a stanza used by XMPP components to authenticate on XMPP
  # component port.
  class Handshake < Extension
    include Packet
    class_getter xml_name : String = "handshake"

    property value : Node? = nil

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name

      cls = new()
      node.children.select(&.element?).each do |child|
        cls.value = Node.new child
        break
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name) do
        value.try &.to_xml xml
      end
    end

    def name : String
      "component:handshake"
    end
  end

  # Component delegation
  # XEP-0355

  # Delegation can be used both on message (for delegated) and IQ (for Forwarded),
  # depending on the context.

  class Delegation < MsgExtension
    include IQPayload
    property xml_name : XMLName = XMLName.new("urn:xmpp:delegation:1 delegation")
    property forwarded : Forwarded? = nil # This is used in iq to wrap delegated iqs
    property delegated : Delegated? = nil # This is used in a message to confirm delegated namespace

    def self.new(node : XML::Node)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "forwarded"
          begin
            cls.forwarded = Forwarded.new(child)
          rescue
          end
        when "delegated"
          begin
            cls.delegated = Delegated.new(child)
          rescue
          end
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(xml_name.local, xmlns: xml_name.space) do
        forwarded.try &.to_xml xml
        delegated.try &.to_xml xml
      end
    end

    def namespace : String
      xml_name.space
    end

    def name : String
      xml_name.local
    end
  end

  class Delegated
    property xml_name : String = "delegated"
    property namespace : String = ""

    def self.new(node : XML::Node)
      cls = new()
      raise "Invalid node(#{node.name}, expecting #{cls.xml_name}" unless (node.name == cls.xml_name)
      node.attributes.each do |attr|
        case attr.name
        when "namespace" then cls.namespace = attr.children[0].content
        end
      end
      cls
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(xml : XML::Builder)
      xml.element(xml_name, Hash{"namespace" => namespace})
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new("urn:xmpp:delegation:1", "delegation"), Delegation)
  Registry.map_extension(PacketType::IQ, XMLName.new("urn:xmpp:delegation:1", "delegation"), Delegation)
end
