require "../registry"
require "../../xmpp"

module XMPP::Stanza
  # NS_MAM is the XEP-0313 Message Archive Management namespace.
  NS_MAM = "urn:xmpp:mam:2"

  # RSM_NS is the XEP-0059 Result Set Management namespace used to page MAM
  # queries.
  RSM_NS = "http://jabber.org/protocol/rsm"

  # MAMQuery implements the IQ payload of XEP-0313 - Message Archive
  # Management.
  #
  # A query requests archived messages, optionally filtered by the chat partner
  # (with), a time range (start/end), and paged via RSM (max/after). The
  # filter is expressed as a jabber:x:data submit form; paging as a
  # jabber:iq:rsm set. The server answers the IQ with a MAMFin and streams the
  # archived messages as Message stanzas carrying MAMResult payloads.
  class MAMQuery < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_MAM, "query")
    property queryid : String = ""
    property with_jid : String = ""
    property start : Time? = nil
    property finish : Time? = nil
    property max : Int32 = 0
    property after : String = ""

    def self.new(xml : String)
      doc = XML.parse(xml)
      root = doc.first_element_child
      if root
        new(root)
      else
        raise "Invalid XML"
      end
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        cls.queryid = attr.children[0].content if attr.name == "queryid"
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "x"
          extract_form(cls, child)
        when "set"
          extract_rsm(cls, child)
        end
      end
      cls
    end

    private def self.extract_form(cls : MAMQuery, node : XML::Node)
      node.children.select(&.element?).each do |field|
        next unless field.name == "field"
        var = field["var"]? || ""
        value = field.children.select(&.element?).find { |c| c.name == "value" }.try(&.content)
        case var
        when "with"  then cls.with_jid = value.to_s
        when "start" then cls.start = parse_time(value.to_s)
        when "end"   then cls.finish = parse_time(value.to_s)
        end
      end
    end

    private def self.extract_rsm(cls : MAMQuery, node : XML::Node)
      node.children.select(&.element?).each do |child|
        cls.max = child.content.to_i32 if child.name == "max"
        cls.after = child.content if child.name == "after"
      end
    end

    private def self.parse_time(value : String) : Time?
      return nil if value.blank?
      Time.parse_iso8601(value)
    rescue ArgumentError
      nil
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["queryid"] = queryid unless queryid.blank?
      xml.element(@@xml_name.local, dict) do
        xml.element("x", xmlns: "jabber:x:data", type: "submit") do
          xml.element("field", var: "FORM_TYPE", type: "hidden") do
            xml.element("value") { xml.text NS_MAM }
          end
          unless with_jid.blank?
            xml.element("field", var: "with") do
              xml.element("value") { xml.text with_jid }
            end
          end
          if since = start
            xml.element("field", var: "start") do
              xml.element("value") { xml.text format_time(since) }
            end
          end
          if until_time = finish
            xml.element("field", var: "end") do
              xml.element("value") { xml.text format_time(until_time) }
            end
          end
        end
        unless max == 0 && after.blank?
          xml.element("set", xmlns: RSM_NS) do
            xml.element("max") { xml.text max.to_s } unless max == 0
            xml.element("after") { xml.text after } unless after.blank?
          end
        end
      end
    end

    private def format_time(time : Time) : String
      time.to_utc.to_s("%Y-%m-%dT%H:%M:%SZ")
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # MAMFin is the IQ result payload of a MAM query. complete is true when all
  # matching messages have been streamed; the fin may carry a paging set for
  # further queries.
  class MAMFin < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_MAM, "fin")
    property complete : Bool = false
    property stable : Bool = true

    def self.new(xml : String)
      doc = XML.parse(xml)
      root = doc.first_element_child
      if root
        new(root)
      else
        raise "Invalid XML"
      end
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      cls.complete = node["complete"]? == "true"
      cls.stable = node["stable"]? != "false"
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["complete"] = "true" if complete
      dict["stable"] = "false" unless stable
      xml.element(@@xml_name.local, dict)
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_MAM, "query"), MAMQuery)
  Registry.map_extension(PacketType::IQ, XMLName.new(NS_MAM, "fin"), MAMFin)
end
