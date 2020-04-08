require "../../registry"
require "../../../xmpp"

module XMPP::Stanza
  # Answer as defined in Stream Management spec
  # Reference: https://xmpp.org/extensions/xep-0198.html#acking
  class SMAnswer < SMFeature
    include Packet
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:sm:3 a")
    property h : UInt32 = 0_u32

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "h" then cls.h = attr.children[0].content.to_u32
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space unless @@xml_name.space.blank?
      dict["h"] = h.to_s unless h == 0

      elem.element(@@xml_name.local, dict)
    end

    def name : String
      "Stream Management: answer"
    end
  end
end
