require "./registry"
require "../stanza"

module XMPP::Stanza
  # XEP-0352: Client State Indication - https://xmpp.org/extensions/xep-0352.html
  NS_CSI = "urn:xmpp:csi:0"

  class CSIActive < Extension
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_CSI, "active")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      new()
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      @@xml_name.local
    end
  end

  class CSIInactive < Extension
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_CSI, "inactive")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      new()
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      @@xml_name.local
    end
  end
end
