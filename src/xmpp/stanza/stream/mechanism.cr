require "../../stanza"

module XMPP::Stanza
  # Mechanisms
  # Reference: RFC 6120 - https://tools.ietf.org/html/rfc6120#section-6.4.1
  # XEP-0440: SASL Channel-Binding Type Capability
  # XEP-0480: SASL Upgrade Tasks
  private class SASLMechanisms
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-sasl mechanisms")
    property mechanism : Array(String) = Array(String).new
    # XEP-0440: Server advertises supported channel binding types
    property channel_binding_types : Array(String) = Array(String).new
    # XEP-0480: Server advertises supported upgrade tasks
    property upgrade_tasks : Array(String) = Array(String).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        ns = child.namespace.try &.href
        case child.name
        when "mechanism"
          cls.mechanism << child.content
        when "channel-binding"
          # XEP-0440: <channel-binding type="tls-exporter"/>
          if type_attr = child.attributes["type"]?
            cls.channel_binding_types << type_attr.content
          end
        when "upgrade"
          # XEP-0480: <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-256</upgrade>
          if ns == "urn:xmpp:sasl:upgrade:0"
            cls.upgrade_tasks << child.content
          end
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        mechanism.each do |v|
          xml.element("mechanism") { xml.text v }
        end
        channel_binding_types.each do |cb_type|
          xml.element("channel-binding", {"type" => cb_type})
        end
        upgrade_tasks.each do |task|
          xml.element("upgrade", {"xmlns" => "urn:xmpp:sasl:upgrade:0"}) { xml.text task }
        end
      end
    end

    # Check if server supports a specific channel binding type
    def supports_channel_binding?(cb_type : String) : Bool
      channel_binding_types.includes?(cb_type)
    end

    # Get the best available channel binding type for TLS version
    def best_channel_binding_type(tls_version : String) : String?
      case tls_version
      when "TLSv1.3"
        # Prefer tls-exporter for TLS 1.3
        return "tls-exporter" if supports_channel_binding?("tls-exporter")
        return "tls-server-end-point" if supports_channel_binding?("tls-server-end-point")
      else
        # For TLS 1.2 and earlier, prefer tls-unique
        return "tls-unique" if supports_channel_binding?("tls-unique")
        return "tls-server-end-point" if supports_channel_binding?("tls-server-end-point")
      end
      nil
    end

    # XEP-0480: Check if server supports a specific upgrade task
    def supports_upgrade?(task : String) : Bool
      upgrade_tasks.includes?(task)
    end

    # XEP-0480: Get available SCRAM upgrade tasks
    def available_scram_upgrades : Array(String)
      upgrade_tasks.select(&.starts_with?("UPGR-SCRAM-"))
    end
  end
end
