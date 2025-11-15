require "../../stanza"

module XMPP::Stanza
  # XEP-0388: Extensible SASL Profile (SASL2)
  # SASL2 Authentication feature in stream features
  class SASL2Authentication
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:sasl:2", "authentication")
    property mechanisms : Array(String) = Array(String).new
    property inline_features : Array(Node) = Array(Node).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "mechanism"
          cls.mechanisms << child.content
        when "inline"
          # Parse inline features that can be negotiated during auth
          child.children.select(&.element?).each do |inline_child|
            cls.inline_features << Node.new(inline_child)
          end
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        mechanisms.each do |mech|
          xml.element("mechanism") { xml.text mech }
        end
        unless inline_features.empty?
          xml.element("inline") do
            inline_features.each(&.to_xml(xml))
          end
        end
      end
    end

    # Check if a specific mechanism is supported
    def supports_mechanism?(mechanism : String) : Bool
      mechanisms.includes?(mechanism)
    end

    # Check if inline feature is supported
    def supports_inline?(namespace : String) : Bool
      inline_features.any? { |ftr| ftr.namespace == namespace }
    end
  end
end
