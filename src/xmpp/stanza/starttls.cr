require "../stanza"

module XMPP::Stanza
  # Used during stream initiation / session establishment
  class TLSProceed
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-tls proceed")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      new()
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space)
    end
  end

  private class TLSFailure
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-tls failure")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      new()
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space)
    end
  end
end
