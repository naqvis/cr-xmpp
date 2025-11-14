require "../../registry"
require "../../../xmpp"

module XMPP::Stanza
  # Request as defined in Stream Management spec
  # Reference: https://xmpp.org/extensions/xep-0198.html#acking
  class SMRequest < SMFeature
    include Packet
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:sm:3 r")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      new()
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      "Stream Management: request"
    end
  end
end
