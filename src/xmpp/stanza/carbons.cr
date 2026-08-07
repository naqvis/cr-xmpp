require "./registry"
require "./forwarded"
require "../../xmpp"

module XMPP::Stanza
  NS_CARBONS = "urn:xmpp:carbons:2"

  # CarbonsEnable implements the enable request of XEP-0280 - Message
  # Carbons. It is sent as an IQ-set to the user's own bare JID after the
  # initial presence, asking the server to carbon-copy the user's messages on
  # all other connected resources.
  class CarbonsEnable < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_CARBONS, "enable")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      new()
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # CarbonsDisable implements the disable request of XEP-0280. It is sent as
  # an IQ-set to the user's own bare JID to stop carbon copies.
  class CarbonsDisable < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_CARBONS, "disable")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      new()
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # CarbonSent is the message payload defined by XEP-0280 for messages sent by
  # one of the user's other resources. The wrapped forwarded stanza carries
  # the original message plus any delay information.
  class CarbonSent < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(NS_CARBONS, "sent")
    property forwarded : Forwarded? = nil

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
        cls.forwarded = Forwarded.new(child) if child.name == "forwarded"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        forwarded.try &.to_xml xml
      end
    end

    def name : String
      @@xml_name.local
    end
  end

  # CarbonReceived is the message payload defined by XEP-0280 for messages
  # received on one of the user's other resources.
  class CarbonReceived < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(NS_CARBONS, "received")
    property forwarded : Forwarded? = nil

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
        cls.forwarded = Forwarded.new(child) if child.name == "forwarded"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        forwarded.try &.to_xml xml
      end
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_CARBONS, "enable"), CarbonsEnable)
  Registry.map_extension(PacketType::IQ, XMLName.new(NS_CARBONS, "disable"), CarbonsDisable)
  Registry.map_extension(PacketType::Message, XMLName.new(NS_CARBONS, "sent"), CarbonSent)
  Registry.map_extension(PacketType::Message, XMLName.new(NS_CARBONS, "received"), CarbonReceived)
end
