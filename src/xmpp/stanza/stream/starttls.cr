require "../../stanza"

module XMPP::Stanza
  # StartTLS feature
  # Reference: RFC 6120 - https://tools.ietf.org/html/rfc6120#section-5.4
  private class TLSStartTLS
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-tls starttls")
    property required : Bool = false

    def initialize(@required = false)
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "required" then cls.required = true
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.element("required") if required
      end
    end
  end
end
