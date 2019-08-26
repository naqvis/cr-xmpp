require "../registry"
require "../../xmpp"

module XMPP::Stanza
  #  Software Version (XEP-0092)
  class Version < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new("jabber:iq:version", "query")
    property name : String = ""
    property version : String = ""
    property os : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "name"    then pr.name = child.content
        when "version" then pr.version = child.content
        when "os"      then pr.os = child.content
        end
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element("name") { elem.text name } unless name.blank?
        elem.element("version") { elem.text version } unless version.blank?
        elem.element("os") { elem.text os } unless os.blank?
      end
    end

    # Set all software version info
    def set_info(name : String, version : String, os : String)
      @name = name
      @version = version
      @os = os
    end

    def namespace : String
      @@xml_name.space
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new("jabber:iq:version", "query"), Version)
end
