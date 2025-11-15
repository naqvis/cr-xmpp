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
  # XEP-0355: Namespace Delegation

  # Delegation can be used both on message (for delegated) and IQ (for Forwarded),
  # depending on the context.

  class Delegation < MsgExtension
    include IQPayload
    property xml_name : XMLName = XMLName.new("urn:xmpp:delegation:2 delegation")
    property forwarded : Forwarded? = nil                        # This is used in iq to wrap delegated iqs
    property delegated : Array(Delegated) = Array(Delegated).new # Multiple delegations possible

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
            cls.delegated << Delegated.new(child)
          rescue
          end
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(xml_name.local, xmlns: xml_name.space) do
        forwarded.try &.to_xml xml
        delegated.each(&.to_xml(xml))
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
    property attributes : Array(DelegatedAttribute) = Array(DelegatedAttribute).new

    def self.new(node : XML::Node)
      cls = new()
      raise "Invalid node(#{node.name}, expecting #{cls.xml_name}" unless node.name == cls.xml_name
      node.attributes.each do |attr|
        case attr.name
        when "namespace" then cls.namespace = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end

      # Parse attribute filters
      node.children.select(&.element?).each do |child|
        if child.name == "attribute"
          cls.attributes << DelegatedAttribute.new(child)
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
      xml.element(xml_name, Hash{"namespace" => namespace}) do
        attributes.each(&.to_xml(xml))
      end
    end
  end

  class DelegatedAttribute
    property xml_name : String = "attribute"
    property name : String = ""

    def self.new(node : XML::Node)
      cls = new()
      raise "Invalid node(#{node.name}, expecting #{cls.xml_name}" unless node.name == cls.xml_name
      node.attributes.each do |attr|
        case attr.name
        when "name" then cls.name = attr.children[0].content
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(xml_name, Hash{"name" => name})
    end
  end

  # XEP-0356: Privileged Entity

  class Privilege < MsgExtension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:privilege:2 privilege")
    property forwarded : Forwarded? = nil
    property perms : Array(Perm) = Array(Perm).new

    def self.new(node : XML::Node)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "forwarded"
          begin
            cls.forwarded = Forwarded.new(child)
          rescue
          end
        when "perm"
          begin
            cls.perms << Perm.new(child)
          rescue
          end
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        forwarded.try &.to_xml xml
        perms.each(&.to_xml(xml))
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  class Perm
    property xml_name : String = "perm"
    property access : String = ""                                         # roster, message, iq, presence
    property type : String = ""                                           # none, get, set, both, outgoing
    property push : String = ""                                           # true, false (for roster)
    property namespaces : Array(PermNamespace) = Array(PermNamespace).new # for IQ

    def self.new(node : XML::Node)
      cls = new()
      raise "Invalid node(#{node.name}, expecting #{cls.xml_name}" unless node.name == cls.xml_name
      node.attributes.each do |attr|
        case attr.name
        when "access" then cls.access = attr.children[0].content
        when "type"   then cls.type = attr.children[0].content
        when "push"   then cls.push = attr.children[0].content
        end
      end

      # Parse namespace elements for IQ permissions
      node.children.select(&.element?).each do |child|
        if child.name == "namespace"
          cls.namespaces << PermNamespace.new(child)
        end
      end

      cls
    end

    def to_xml(xml : XML::Builder)
      attrs = Hash(String, String).new
      attrs["access"] = access unless access.blank?
      attrs["type"] = type unless type.blank?
      attrs["push"] = push unless push.blank?

      xml.element(xml_name, attrs) do
        namespaces.each(&.to_xml(xml))
      end
    end
  end

  class PermNamespace
    property xml_name : String = "namespace"
    property value : String = ""

    def self.new(node : XML::Node)
      cls = new()
      raise "Invalid node(#{node.name}, expecting #{cls.xml_name}" unless node.name == cls.xml_name
      cls.value = node.content
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(xml_name) { xml.text value }
    end
  end

  # Register both v1 and v2 namespaces for backward compatibility
  Registry.map_extension(PacketType::Message, XMLName.new("urn:xmpp:delegation:1", "delegation"), Delegation)
  Registry.map_extension(PacketType::IQ, XMLName.new("urn:xmpp:delegation:1", "delegation"), Delegation)
  Registry.map_extension(PacketType::Message, XMLName.new("urn:xmpp:delegation:2", "delegation"), Delegation)
  Registry.map_extension(PacketType::IQ, XMLName.new("urn:xmpp:delegation:2", "delegation"), Delegation)

  Registry.map_extension(PacketType::Message, XMLName.new("urn:xmpp:privilege:2", "privilege"), Privilege)
  Registry.map_extension(PacketType::IQ, XMLName.new("urn:xmpp:privilege:2", "privilege"), Privilege)
end
