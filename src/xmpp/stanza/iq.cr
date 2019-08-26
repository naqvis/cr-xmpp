require "xml"
require "./error"
require "./packet"
require "./registry"
require "./node"

module XMPP::Stanza
  # # IQ Packet
  # IQ implements RFC 6120 - A.5 Client Namespace (a part)
  # [RFC 3920 Section 9.2.3 - IQ Semantics](http://xmpp.org/rfcs/rfc3920.html#rfc.section.9.2.3)
  #
  # Info/Query, or IQ, is a request-response mechanism, similar in some ways
  # to HTTP. The semantics of IQ enable an entity to make a request of, and
  # receive a response from, another entity. The data content of the request
  # and response is defined by the namespace declaration of a direct child
  # element of the IQ element, and the interaction is tracked by the
  # requesting entity through use of the 'id' attribute. Thus, IQ interactions
  # follow a common pattern of structured data exchange such as get/result or
  # set/result (although an error may be returned in reply to a request if
  # appropriate).
  # ## "ID" Attribute
  #
  # IQ Stanzas require the ID attribute be set.
  #
  # ## "Type" Attribute
  #
  # * `:get` -- The stanza is a request for information or requirements.
  #
  # * `:set` -- The stanza provides required data, sets new values, or
  #   replaces existing values.
  #
  # * `:result` -- The stanza is a response to a successful get or set request.
  #
  # * `:error` -- An error has occurred regarding processing or delivery of a
  #   previously-sent get or set (see Stanza Errors).
  #
  class IQ < Extension
    class_getter xml_name : String = "iq"
    include Packet
    include Attrs
    # We can only have one payload on IQ:
    #   "An IQ stanza of type "get" or "set" MUST contain exactly one
    #    child element, which specifies the semantics of the particular
    #    request."
    property payload : IQPayload? = nil
    property error : Error? = nil
    # Any is used to decode unknown payloads
    property any : Node? = nil

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
      pr.load_attrs(node)
      node.children.select(&.element?).each do |child|
        case child.name
        when "error" then pr.error = Error.new(child)
        else
          begin
            ext = Registry.get_iq_extension XMLName.new(child.namespace.try &.href || "", child.name), child
            if !ext.nil?
              pr.payload = ext if ext.is_a?(IQPayload)
            end
          rescue ex
            pr.any = Node.new(child)
            XMPP::Logger.warn ex
          end
        end
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      dict = attr_hash

      elem.element(@@xml_name, dict) do
        payload.try &.to_xml elem
        error.try &.to_xml elem
        any.try &.to_xml elem
      end
    end

    def name : String
      @@xml_name
    end

    def make_error(err : Error)
      self.type = "error"
      self.from, self.to = self.to, self.from
      self.error = err
    end

    # Version builds a default software version payload
    def version
      d = Version.new
      @payload = d
      d
    end

    # disco_info builds a default DiscoInfo payload
    def disco_info
      d = DiscoInfo.new
      @payload = d
      d
    end

    # disco_items builds a default DiscoItems payload
    def disco_items
      d = DiscoItems.new
      @payload = d
      d
    end
  end
end

require "./iq/*"
