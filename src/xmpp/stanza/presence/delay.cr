require "../registry"
require "../../xmpp"

module XMPP::Stanza
  # XEP-0203 Delayed Delivery http://www.xmpp.org/extensions/xep-0203.html
  class DelayPresence < PresExtension
    class_getter xml_name : XMLName = XMLName.new("urn:xmpp:delay delay")
    property from : String = ""
    property stamp : Time = Time.utc(seconds: 0, nanoseconds: 0)

    def self.new(node : XML::Node)
      ns = node.namespace.try &.href || ""
      raise "Invalid node(#{ns} #{node.name}) expecting: #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                                    (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "from"  then cls.from = attr.children[0].content
        when "stamp" then cls.stamp = DELAY_DATE_TIME_FORMAT.parse(attr.children[0].content)
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["from"] = from unless from.blank?
      dict["stamp"] = DELAY_DATE_TIME_FORMAT.format(stamp) unless stamp == Time.utc(seconds: 0, nanoseconds: 0)
      elem.element(@@xml_name.local, dict)
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Presence, XMLName.new("urn:xmpp:delay", "delay"), DelayPresence)
end
