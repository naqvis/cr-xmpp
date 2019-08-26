require "../registry"
require "../../xmpp"

module XMPP::Stanza
  MSG_HINTS_NS = "urn:xmpp:hints"

  # Support for:
  # - XEP-0334 - Message Processing Hints: https://xmpp.org/extensions/xep-0334.html
  #  defines a way to include hints to entities routing or receiving a message.
  class StoreHint < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_HINTS_NS, "store")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name
      @@xml_name.local
    end
  end

  class NoStoreHint < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_HINTS_NS, "no-store")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name
      @@xml_name.local
    end
  end

  class NoPermanentStoreHint < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_HINTS_NS, "no-permanent-store")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name
      @@xml_name.local
    end
  end

  class NoCopyHint < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_HINTS_NS, "no-copy")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new(MSG_HINTS_NS, "store"), StoreHint)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_HINTS_NS, "no-store"), NoStoreHint)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_HINTS_NS, "no-permanent-store"), NoPermanentStoreHint)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_HINTS_NS, "no-copy"), NoCopyHint)
end
