require "../registry"
require "../../xmpp"

module XMPP::Stanza
  NS_PRIVATE_STORAGE = "jabber:iq:private"

  # PrivateQuery implements XEP-0049 - Private XML Storage.
  #
  # The query carries a single arbitrary XML element whose namespace and local
  # name identify the stored data. A get request includes an empty version of
  # that element so the server knows what to return; a set request stores the
  # element verbatim. The element is preserved as a generic Node so any data
  # can round-trip.
  class PrivateQuery < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_PRIVATE_STORAGE, "query")
    property data : Node? = nil

    def self.new(xml : String)
      doc = XML.parse(xml)
      root = doc.first_element_child
      if root
        new(root)
      else
        raise "Invalid XML"
      end
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      child = node.children.select(&.element?).first?
      cls.data = Node.new(child) if child
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        @data.try &.to_xml xml
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_PRIVATE_STORAGE, "query"), PrivateQuery)
end
