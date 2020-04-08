require "../registry"
require "../../stanza"

module XMPP::Stanza
  # vCard-Based Avatars Presence extension
  # VCardPresence implements XEP-0153 - vCard-Based Avatars https://xmpp.org/extensions/xep-0153.html
  class VCardPresence < PresExtension
    class_getter xml_name : XMLName = XMLName.new("vcard-temp:x:update x")
    property photo : Bytes? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "photo" then cls.photo = child.content.to_slice
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        if (p = photo)
          elem.element("photo") { elem.text String.new(p) }
        end
      end
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Presence, XMLName.new("vcard-temp:x:update", "x"), VCardPresence)
end
