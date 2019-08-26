require "../../stanza"

module XMPP::Stanza
  # Mechanisms
  # Reference: RFC 6120 - https://tools.ietf.org/html/rfc6120#section-6.4.1
  private class SASLMechanisms
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-sasl mechanisms")
    property mechanism : Array(String) = Array(String).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "mechanism" then cls.mechanism << child.content
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        mechanism.each do |v|
          elem.element(v)
        end
      end
    end
  end
end
