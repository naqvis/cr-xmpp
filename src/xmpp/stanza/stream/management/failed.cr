require "../../registry"
require "../../../xmpp"

module XMPP::Stanza
  # Failed as defined in Stream Management spec
  # Reference: https://xmpp.org/extensions/xep-0198.html#acking
  class SMFailed < SMFeature
    include Packet
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:sm:3 failed")
    property cause : Node? = nil
    property error_type : String = "" # Decoded error type (e.g., "item-not-found", "unexpected-request")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        cls.cause = Node.new(child)
        # Extract the error type from the child element name
        # Common errors: item-not-found, unexpected-request, feature-not-implemented
        cls.error_type = child.name
        break
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        cause.try &.to_xml xml
      end
    end

    def name : String
      "Stream Management: failed"
    end

    # Human-readable error description
    def error_description : String
      case error_type
      when "item-not-found"
        "Session not found or expired"
      when "unexpected-request"
        "Stream management request was unexpected"
      when "feature-not-implemented"
        "Stream management feature not implemented"
      when "service-unavailable"
        "Stream management service unavailable"
      else
        error_type.blank? ? "Unknown error" : error_type
      end
    end
  end
end
