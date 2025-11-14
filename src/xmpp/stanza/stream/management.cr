require "../../stanza"

module XMPP::Stanza
  # StreamManagement
  # Reference: XEP-0198 - https://xmpp.org/extensions/xep-0198.html#feature
  private class StreamManagement
    class_getter xml_name : XMLName = XMLName.new(NS_STREAM_MANAGEMENT, "sm")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      new()
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space)
    end
  end

  abstract class SMFeature < Extension
  end

  module SMFeatureHandler
    extend self

    def parse(node : XML::Node) : Packet
      case node.name
      when "enabled" then SMEnabled.new node
      when "resumed" then SMResumed.new node
      when "r"       then SMRequest.new node
      when "h"       then SMAnswer.new node
      when "failed"  then SMFailed.new node
      else
        raise "unexpected XMPP packet #{node.namespace.try &.href}<#{node.name}>"
      end
    end
  end
end

require "./management/*"
