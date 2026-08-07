require "../registry"
require "../../xmpp"
require "../forwarded"

module XMPP::Stanza
  # MAMResult is the message payload carrying one archived message, streamed by
  # the server in response to a MAM query. It wraps the original stanza in a
  # Forwarded element (XEP-0297) so the recipient, timestamp, and content are
  # preserved.
  class MAMResult < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(NS_MAM, "result")
    property queryid : String = ""
    property id : String = ""
    property forwarded : Forwarded? = nil

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
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == NS_MAM) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "queryid" then cls.queryid = attr.children[0].content
        when "id"      then cls.id = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        cls.forwarded = Forwarded.new(child) if child.name == "forwarded"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["queryid"] = queryid unless queryid.blank?
      dict["id"] = id unless id.blank?
      xml.element(@@xml_name.local, dict) do
        forwarded.try &.to_xml xml
      end
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new(NS_MAM, "result"), MAMResult)
end
