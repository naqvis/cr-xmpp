require "../registry"
require "../../stanza"

module XMPP::Stanza
  # MUC Presence extension
  # MucPresence implements XEP-0045: Multi-User Chat - 19.1
  class MucPresence < PresExtension
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/muc x")
    property password : String = ""
    property history : History? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "password" then cls.password = child.content
        when "history"  then cls.history = History.new(child)
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element("password") { elem.text password } unless password.blank?
        history.try &.to_xml elem
      end
    end

    def name : String
      @@xml_name.local
    end
  end

  DATE_TIME_FORMAT = Time::Format.new "%Y-%m-%dT%H:%M:%SZ", Time::Location::UTC

  # History implements XEP-0045: Multi-User Chat - 19.1
  class History
    class_getter xml_name : String = "history"
    property max_chars : Int32 = -1
    property max_stanzas : Int32 = -1
    property seconds : Int32 = -1
    property since : Time = Time.utc(seconds: 0, nanoseconds: 0)

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "maxchars"   then cls.max_chars = attr.children[0].content.to_i32
        when "maxstanzas" then cls.max_stanzas = attr.children[0].content.to_i32
        when "seconds"    then cls.seconds = attr.children[0].content.to_i32
        when "since"      then cls.since = DATE_TIME_FORMAT.parse(attr.children[0].content)
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new

      dict["maxchars"] = max_chars.to_s unless max_chars == -1
      dict["maxstanzas"] = max_stanzas.to_s unless max_stanzas == -1
      dict["seconds"] = seconds.to_s unless seconds == -1
      dict["since"] = DATE_TIME_FORMAT.format(since) unless since == Time.utc(seconds: 0, nanoseconds: 0)

      elem.element(@@xml_name, dict)
    end
  end

  Registry.map_extension(PacketType::Presence, XMLName.new("http://jabber.org/protocol/muc", "x"), MucPresence)
end
