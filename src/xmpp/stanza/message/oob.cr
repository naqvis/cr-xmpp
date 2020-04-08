require "../registry"
require "../../xmpp"

module XMPP::Stanza
  # Support for:
  # - XEP-0066 - Out of Band Data: https://xmpp.org/extensions/xep-0066.html

  class OOB < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("jabber:x:oob", "x")
    property url : String = ""
    property desc : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "url"  then pr.url = child.content
        when "desc" then pr.desc = child.content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element("url") { elem.text url } unless url.blank?
        elem.element("desc") { elem.text desc } unless desc.blank?
      end
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new("jabber:x:oob", "x"), OOB)
end
