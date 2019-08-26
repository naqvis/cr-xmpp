require "./registry"

module XMPP::Stanza
  # RFC 6120: part of A.5 Client Namespace and A.6 Server Namespace
  ERROR_AUTH     = "auth"
  ERROR_CANCEL   = "cancel"
  ERROR_CONTINUE = "continue"
  ERROR_MODIFY   = "modify"
  ERROR_WAIT     = "wait"

  # Message Packet
  # XMPP Errors
  # Error is an XMPP stanza payload that is used to report error on message,
  # presence or iq stanza.
  # It is intended to be added in the payload of the erroneous stanza.
  class Error < Extension
    class_getter xml_name : String = "error"
    property code : Int32 = 0
    property type : String = ""
    property reason : String = ""
    property text : String = ""

    def self.new(xml : String)
      doc = XML.parse(xml)
      root = doc.first_element_child
      if (root)
        new(root)
      else
        raise "Invalid XML"
      end
    end

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "code" then pr.code = attr.children[0].content.to_i32
        when "type" then pr.type = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        ns = XMLName.new(child.namespace.try &.href || " ")

        if ns.space == "urn:ietf:params:xml:ns:xmpp-stanzas" && child.name == "text"
          pr.text = child.content
        elsif ns.space == "urn:ietf:params:xml:ns:xmpp-stanzas"
          pr.reason = child.name
        end
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      dict = Hash(String, String).new
      dict["code"] = code.to_s unless code == 0
      dict["type"] = type unless type.blank?

      elem.element(@@xml_name, dict) do
        unless reason.blank?
          elem.element(reason, xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas")
        end
        elem.element("text", xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas") { elem.text text } unless text.blank?
      end
    end

    def name : String
      @@xml_name
    end
  end
end
