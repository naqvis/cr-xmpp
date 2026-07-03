require "../registry"
require "../../xmpp"

module XMPP::Stanza
  MSG_EME_NS = "urn:xmpp:eme:0"

  # XEP-0380 Explicit Message Encryption.
  # https://xmpp.org/extensions/xep-0380.html
  #
  # A small marker that tells receiving clients what kind of
  # encrypted payload is inside the stanza, without having to
  # peek at the actual encryption extension. Without it,
  # Conversations and other clients can fail to surface an
  # encrypted message at all (no notification, no chat bubble)
  # when they cannot decrypt the payload, they don't even know
  # there is anything to display.
  #
  # well-known namespaces (from the XEP registry):
  #   urn:xmpp:omemo:2       OMEMO 2
  #   eu.siacs.conversations.axolotl  OMEMO legacy
  #   urn:xmpp:openpgp:0     OpenPGP for XMPP (OX)
  #   jabber:x:encrypted     legacy OpenPGP (XEP-0027)
  class ExplicitMessageEncryption < MsgExtension
    OMEMO_LEGACY_NS = "eu.siacs.conversations.axolotl"
    OMEMO_V2_NS     = "urn:xmpp:omemo:2"

    class_getter xml_name : XMLName = XMLName.new(MSG_EME_NS, "encryption")
    property namespace : String = ""
    property name_attr : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name})" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                          (node.name == @@xml_name.local)
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "namespace" then pr.namespace = attr.children[0].content
        when "name"      then pr.name_attr = attr.children[0].content
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["namespace"] = namespace unless namespace.blank?
      dict["name"] = name_attr unless name_attr.blank?
      xml.element(@@xml_name.local, dict)
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new(MSG_EME_NS, "encryption"), ExplicitMessageEncryption)
end
