require "../../registry"
require "../../../xmpp"

module XMPP::Stanza
  # Failed as defined in Stream Management spec
  # Reference: https://xmpp.org/extensions/xep-0198.html#acking
  class SMFailed < SMFeature
    include Packet
    # TODO: Handle decoding error cause (need custom parsing).
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:sm:3 failed")
    property cause : Node? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        cls.cause = Node.new(child)
        break
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        cause.try &.to_xml elem
      end
    end

    def name : String
      "Stream Management: failed"
    end
  end
end
