require "../registry"
require "../../stanza"

module XMPP::Stanza
  # StreamError Packet
  class StreamError
    include Packet
    class_getter xml_name : XMLName = XMLName.new("http://etherx.jabber.org/streams error")
    property error : Node? = nil
    property text : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        if child.name == "text" && child.namespace.try &.href == "urn:ietf:params:xml:ns:xmpp-streams"
          cls.text = child.content
        else
          cls.error = Node.new(child)
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element("text") { elem.text text } unless text.blank?
        error.try &.to_xml elem
      end
    end

    def name : String
      "stream:error"
    end
  end
end
