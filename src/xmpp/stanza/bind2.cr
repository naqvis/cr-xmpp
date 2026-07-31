require "../stanza"
require "./node"

module XMPP::Stanza
  # XEP-0386 Bind 2 feature advertised within the SASL2 inline element.
  class Bind2Feature
    class_getter xml_name : XMLName = XMLName.new(NS_BIND2, "bind")
    getter features : Array(String) = Array(String).new

    def self.new(node : XML::Node)
      unless node.namespace.try(&.href) == @@xml_name.space && node.name == @@xml_name.local
        raise ParseError.new("Invalid node(#{node.name}), expecting #{@@xml_name}")
      end

      feature = new
      inline = node.children.find do |child|
        child.element? && child.name == "inline" && child.namespace.try(&.href) == NS_BIND2
      end
      inline.try &.children.select(&.element?).each do |child|
        next unless child.name == "feature" && child.namespace.try(&.href) == NS_BIND2
        if value = child.attributes["var"]?.try(&.content)
          feature.features << value unless value.blank?
        end
      end
      feature
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        unless features.empty?
          xml.element("inline") do
            features.each { |feature| xml.element("feature", {"var" => feature}) }
          end
        end
      end
    end

    def supports?(feature : String) : Bool
      features.includes?(feature)
    end
  end

  # Bind 2 request included by a client in its SASL2 authenticate request.
  class Bind2Request
    class_getter xml_name : XMLName = XMLName.new(NS_BIND2, "bind")
    property tag : String = ""
    getter features : Array(Node) = Array(Node).new

    def initialize(@tag = "", @features = Array(Node).new)
    end

    def self.new(node : XML::Node)
      unless node.namespace.try(&.href) == @@xml_name.space && node.name == @@xml_name.local
        raise ParseError.new("Invalid node(#{node.name}), expecting #{@@xml_name}")
      end

      request = new
      node.children.select(&.element?).each do |child|
        namespace = child.namespace.try(&.href) || ""
        if child.name == "tag" && namespace == NS_BIND2
          request.tag = child.content
        elsif namespace != NS_BIND2
          request.features << Node.new(child)
        end
      end
      request
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.element("tag") { xml.text tag } unless tag.blank?
        features.each(&.to_xml(xml))
      end
    end
  end

  # Bind 2 result included by a server in its SASL2 success response.
  class Bind2Bound
    class_getter xml_name : XMLName = XMLName.new(NS_BIND2, "bound")
    getter features : Array(Node) = Array(Node).new

    def self.new(node : XML::Node)
      unless node.namespace.try(&.href) == @@xml_name.space && node.name == @@xml_name.local
        raise ParseError.new("Invalid node(#{node.name}), expecting #{@@xml_name}")
      end

      bound = new
      node.children.select(&.element?).each { |child| bound.features << Node.new(child) }
      bound
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        features.each(&.to_xml(xml))
      end
    end

    def feature(namespace : String) : Node?
      features.find { |candidate| candidate.namespace == namespace }
    end
  end
end
