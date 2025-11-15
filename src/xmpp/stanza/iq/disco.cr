require "../registry"
require "../../xmpp"

module XMPP::Stanza
  NS_DISCO_INFO = "http://jabber.org/protocol/disco#info"

  # XEP-0030: Service Discovery

  class DiscoInfo < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_DISCO_INFO, "query")
    property node : String = ""
    property identity : Array(Identity) = Array(Identity).new
    property features : Array(Feature) = Array(Feature).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "node" then cls.node = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "identity" then cls.identity << Identity.new(child)
        when "feature"  then cls.features << Feature.new(child)
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space unless @@xml_name.space.blank?
      dict["node"] = node unless node.blank?

      xml.element(@@xml_name.local, dict) do
        identity.each do |v|
          v.to_xml xml
        end
        features.each do |v|
          v.to_xml xml
        end
      end
    end

    def add_identity(name : String, category : String, type : String)
      identity = Identity.new
      identity.name = name
      identity.category = category
      identity.type = type
      @identity << identity
    end

    def add_features(namespace : Array(String))
      namespace.each do |nsp|
        f = Feature.new
        f.var = nsp
        @features << f
      end
    end

    def features=(f : Array(Feature))
      @features = f.dup
    end

    def features=(f : Array(String))
      @features.clear
      add_features f
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  class Identity
    class_getter xml_name : String = "identity"
    property name : String = ""
    property category : String = ""
    property type : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "name"     then cls.name = attr.children[0].content
        when "category" then cls.category = attr.children[0].content
        when "type"     then cls.type = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new

      dict["name"] = name unless name.blank?
      dict["category"] = category unless category.blank?
      dict["type"] = type unless type.blank?

      xml.element(@@xml_name, dict)
    end
  end

  class Feature
    class_getter xml_name : String = "feature"
    property var : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "var" then cls.var = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["var"] = var unless var.blank?

      xml.element(@@xml_name, dict)
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_DISCO_INFO, "query"), DiscoInfo)
end
