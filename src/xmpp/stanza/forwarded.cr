require "../stanza"
require "./packet"

module XMPP::Stanza
  # Forwarded is used to wrapped forwarded stanzas.
  class Forwarded
    property xml_name : XMLName
    property stanza : Packet? = nil

    def initialize
      @xml_name = XMLName.new("urn:xmpp:forward:0 forwarded")
    end

    # transform generic XML content into hierarchical Node structure.
    def self.new(node : XML::Node)
      cls = new()
      raise "Invalid node(#{node.name}, expecting #{cls.xml_name}" unless (node.namespace.try &.href == cls.xml_name.space) &&
                                                                          (node.name == cls.xml_name.local)
      node.children.select(&.element?).each do |child|
        obj = Parser.decode_client(child)
        cls.stanza = obj if obj.is_a?(Packet)
        break
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(xml_name.local, xmlns: xml_name.space) do
        if (s = stanza) && (s.responds_to?(:to_xml))
          s.to_xml xml
        end
      end
    end
  end
end
