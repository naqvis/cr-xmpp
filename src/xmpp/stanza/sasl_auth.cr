require "../stanza"
require "./registry"

module XMPP::Stanza
  # SASLAuth implements SASL Authentication initiation.
  # Reference: https://tools.ietf.org/html/rfc6120#section-6.4.2
  class SASLAuth
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-sasl auth")
    property mechanism : String = ""
    property value : Node? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "mechanism" then cls.mechanism = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        cls.value = Node.new child
        break
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space unless @@xml_name.space.blank?
      dict["mechanism"] = mechanism unless mechanism.blank?

      elem.element(@@xml_name.local, dict) do
        value.try &.to_xml elem
      end
    end
  end

  # SASLSuccess implements SASL Success nonza, sent by server as a result of the
  # SASL auth negotiation.
  # Reference: https://tools.ietf.org/html/rfc6120#section-6.4.6
  class SASLSuccess
    include Packet
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-sasl", "success")

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      new()
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space)
    end

    def name
      "sasl:success"
    end
  end

  # SASLFailure
  class SASLFailure
    include Packet
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-sasl failure")
    property any : Node? = nil # error reason is a subelement

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        cls.any = Node.new child
        break
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        any.try &.to_xml elem
      end
    end

    def name
      "sasl:failure"
    end
  end

  # Resource binding
  # Bind is an IQ payload used during session negotiation to bind user resource
  # to the current XMPP stream.
  # Reference: https://tools.ietf.org/html/rfc6120#section-7
  class Bind < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-bind bind")
    property resource : String = ""
    property jid : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "resource" then cls.resource = child.content
        when "jid"      then cls.jid = child.content
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element("resource") { elem.text resource } unless resource.blank?
        elem.element("jid") { elem.text jid } unless jid.blank?
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # ============================================================================
  # Session (Obsolete)
  # Session is both a stream feature and an obsolete IQ Payload, used to bind a
  # resource to the current XMPP stream on RFC 3121 only XMPP servers.
  # Session is obsolete in RFC 6121. It is added to cr-xmpp for compliance
  # with RFC 3121.
  # Reference: https://xmpp.org/rfcs/rfc3921.html#session
  #
  # This is the draft defining how to handle the transition:
  #    https://tools.ietf.org/html/draft-cridland-xmpp-session-01
  class StreamSession < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new("urn:ietf:params:xml:ns:xmpp-session session")
    property optional : Bool = false # If element does exist, it mean we are not required to open session

    def initialize(@optional = false)
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "optional" then cls.optional = true
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element("optional") if optional
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new("urn:ietf:params:xml:ns:xmpp-bind", "bind"), Bind)
  Registry.map_extension(PacketType::IQ, XMLName.new("urn:ietf:params:xml:ns:xmpp-session", "session"), StreamSession)
end
