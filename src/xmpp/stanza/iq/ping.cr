require "../registry"
require "../../xmpp"

module XMPP::Stanza
  # XEP-0199: XMPP Ping - https://xmpp.org/extensions/xep-0199.html
  class Ping < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:ping ping")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      new()
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new("urn:xmpp:ping", "ping"), Ping)
end
