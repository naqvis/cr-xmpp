require "../registry"
require "../../xmpp"

module XMPP::Stanza
  DIRECT_INVITE_NS = "jabber:x:conference"

  # DirectInvite implements XEP-0249 - Direct MUC Invitations.
  #
  # A user invites another user to a room by sending a message whose payload
  # is an empty <x> element in the "jabber:x:conference" namespace carrying the
  # room JID and optional metadata as attributes. Unlike the mediated MUC
  # invitation (XEP-0045), a direct invitation is sent person-to-person.
  class DirectInvite < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(DIRECT_INVITE_NS, "x")
    property jid : String = ""
    property password : String = ""
    property reason : String = ""
    property thread : String = ""
    property? continue : Bool = false

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
      node.attributes.each do |attr|
        case attr.name
        when "jid"      then cls.jid = attr.children[0].content
        when "password" then cls.password = attr.children[0].content
        when "reason"   then cls.reason = attr.children[0].content
        when "thread"   then cls.thread = attr.children[0].content
        when "continue" then cls.continue = true
        else
          # Ignore unknown attributes.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["jid"] = jid unless jid.blank?
      dict["password"] = password unless password.blank?
      dict["reason"] = reason unless reason.blank?
      dict["thread"] = thread unless thread.blank?
      dict["continue"] = "true" if continue?

      xml.element(@@xml_name.local, dict)
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new(DIRECT_INVITE_NS, "x"), DirectInvite)
end
