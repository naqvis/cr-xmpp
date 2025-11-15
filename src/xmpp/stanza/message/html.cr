require "../registry"
require "../../xmpp"

module XMPP::Stanza
  class HTML < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/xhtml-im", "html")
    property body : HTMLBody? = nil
    property lang : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "lang" then pr.lang = attr.children[0].content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "body" then pr.body = HTMLBody.new(child)
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xml:lang"] = lang unless lang.blank?
      dict["xmlns"] = @@xml_name.space
      xml.element(@@xml_name.local, dict) do
        body.try &.to_xml xml
      end
    end

    def name : String
      @@xml_name.local
    end
  end

  class HTMLBody
    class_getter xml_name : XMLName = XMLName.new("http://www.w3.org/1999/xhtml body")
    # InnerXML MUST be valid xhtml. it will be parsed via `XML.parse_html` when generating the XMPP stanza.
    property inner_xml : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        pr.inner_xml = child.to_xml
      end
      pr
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        get_xhtml xml
      end
    end

    private def get_xhtml(xml : XML::Builder)
      opt = XML::HTMLParserOptions.default | XML::HTMLParserOptions::NOIMPLIED
      doc = XML.parse_html inner_xml, opt
      root = doc.first_element_child
      if node = root
        xml.element(node.name, attrs_to_hash node.attributes) do
          node.children.select(&.text?).each do |child|
            xml.text child.text
          end
          node.children.select(&.element?).each do |child|
            xml.element(child.name, attrs_to_hash child.attributes) { xml.text child.text }
          end
        end
      end
    end

    private def attrs_to_hash(attrs)
      hash = Hash(String, String).new
      attrs.each do |attr|
        hash[attr.name] = attr.children[0].content
      end
      hash
    end
  end

  Registry.map_extension(PacketType::Message, XMLName.new("http://jabber.org/protocol/xhtml-im", "html"), HTML)
end
