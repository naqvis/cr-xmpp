require "../registry"
require "../../xmpp"

module XMPP::Stanza
  MSG_CHAT_STATE_NOTIFICATION_NS = "http://jabber.org/protocol/chatstates"

  # Support for:
  # - XEP-0085 - Chat State Notifications: https://xmpp.org/extensions/xep-0085.html
  class StateActive < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "active")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      @@xml_name.local
    end
  end

  class StateComposing < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "composing")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      @@xml_name.local
    end
  end

  class StateGone < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "gone")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      @@xml_name.local
    end
  end

  class StateInactive < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "inactive")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      @@xml_name.local
    end
  end

  class StatePaused < MsgExtension
    class_getter xml_name : XMLName = XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "paused")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()

      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "active"), StateActive)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "composing"), StateComposing)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "gone"), StateGone)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "inactive"), StateInactive)
  Registry.map_extension(PacketType::Message, XMLName.new(MSG_CHAT_STATE_NOTIFICATION_NS, "paused"), StatePaused)
end
