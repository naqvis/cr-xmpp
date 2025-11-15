require "../registry"
require "../../xmpp"

module XMPP::Stanza
  ROSTER_NS = "jabber:iq:roster"

  # Instant Messaging and Presence
  # RFC6121 - https://xmpp.org/rfcs/rfc6121.html
  class Roster < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(ROSTER_NS, "query")
    property ver : String = ""
    property item : Array(RosterItem) = Array(RosterItem).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "ver" then cls.ver = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "item" then cls.item << RosterItem.new(child)
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space unless @@xml_name.space.blank?
      dict["ver"] = ver unless ver.blank?

      xml.element(@@xml_name.local, dict) do
        item.each do |v|
          v.to_xml xml
        end
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  class RosterItem
    class_getter xml_name : String = "item"
    property group : Array(String) = Array(String).new
    property? approved : Bool = false
    property ask : String = ""
    property jid : String = ""
    property name : String = ""
    property subscription : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "approved"     then cls.approved = attr.children[0].content == "true"
        when "ask"          then cls.ask = attr.children[0].content
        when "jid"          then cls.jid = attr.children[0].content
        when "name"         then cls.name = attr.children[0].content
        when "subscription" then cls.subscription = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "group" then cls.group << child.content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new

      dict["approved"] = approved?.to_s if approved?
      dict["ask"] = ask unless ask.blank?
      dict["jid"] = jid unless jid.blank?
      dict["name"] = name unless name.blank?
      dict["subscription"] = subscription unless subscription.blank?

      xml.element(@@xml_name, dict) do
        group.each do |v|
          xml.element("group") { xml.text v } unless v.blank?
        end
      end
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(ROSTER_NS, "query"), Roster)
end
