require "../../stanza"

module XMPP::Stanza
  # Capabilities
  # Reference: https://xmpp.org/extensions/xep-0115.html#stream
  # "A server MAY include its entity capabilities in a stream feature element so that connecting clients
  # and peer servers do not need to send service discovery requests each time they connect."
  # This is not a stream feature but a way to let client cache server disco info.
  class Caps < PresExtension
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/caps c")
    property hash : String = ""
    property node : String = ""
    property ver : String = ""
    property ext : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "hash" then cls.hash = attr.children[0].content
        when "node" then cls.node = attr.children[0].content
        when "ver"  then cls.ver = attr.children[0].content
        when "ext"  then cls.ext = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space unless @@xml_name.space.blank?
      dict["hash"] = hash unless hash.blank?
      dict["node"] = node unless node.blank?
      dict["ver"] = ver unless ver.blank?
      dict["ext"] = ext unless ext.blank?

      elem.element(@@xml_name.local, dict)
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Presence, XMLName.new("http://jabber.org/protocol/caps c"), Caps)
end
