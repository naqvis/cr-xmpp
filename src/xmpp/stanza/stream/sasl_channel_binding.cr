require "../../stanza"

module XMPP::Stanza
  # XEP-0440: SASL Channel-Binding Type Capability
  class SASLChannelBinding
    class_getter xml_name : XMLName = XMLName.new(NS_SASL_CHANNEL_BINDING, "sasl-channel-binding")
    property types : Array(String) = Array(String).new

    def self.new(node : XML::Node)
      unless node.namespace.try(&.href) == @@xml_name.space && node.name == @@xml_name.local
        raise "Invalid node(#{node.name}), expecting #{@@xml_name}"
      end

      feature = new
      node.children.select(&.element?).each do |child|
        next unless child.name == "channel-binding"
        next unless child.namespace.try(&.href) == @@xml_name.space
        type = child["type"]?
        feature.types << type if type && !type.blank? && !feature.types.includes?(type)
      end
      feature
    end

    def supports?(type : String) : Bool
      types.includes?(type)
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        types.each do |type|
          xml.element("channel-binding", {"type" => type})
        end
      end
    end
  end
end
