require "../../registry"
require "../../../xmpp"

module XMPP::Stanza
  # Enabled as defined in Stream Management spec
  # Reference: https://xmpp.org/extensions/xep-0198.html#enable
  class SMEnabled < SMFeature
    include Packet
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:sm:3 enabled")
    property id : String = ""
    property location : String = ""
    property resume : String = ""
    property max : UInt32 = 0_u32

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "id"       then cls.id = attr.children[0].content
        when "location" then cls.location = attr.children[0].content
        when "resume"   then cls.resume = attr.children[0].content
        when "max"      then cls.max = attr.children[0].content.to_u32
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space unless @@xml_name.space.blank?
      dict["id"] = id unless id.blank?
      dict["location"] = location unless location.blank?
      dict["resume"] = resume unless resume.blank?
      dict["max"] = max.to_s unless max == 0

      elem.element(@@xml_name.local, dict)
    end

    def name : String
      "Stream Management: enabled"
    end
  end
end
