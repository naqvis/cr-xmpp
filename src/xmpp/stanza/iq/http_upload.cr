require "../registry"
require "../../xmpp"

module XMPP::Stanza
  NS_HTTP_UPLOAD = "urn:xmpp:http:upload:0"

  # UploadRequest implements the slot request of XEP-0363 - HTTP File Upload.
  # It is sent as an IQ-get to an upload service, asking for a place to PUT a
  # file of the given size and type.
  class UploadRequest < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_HTTP_UPLOAD, "request")
    property filename : String = ""
    property size : UInt64 = 0_u64
    property content_type : String = ""

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
        case attr.name
        when "filename"     then cls.filename = attr.children[0].content
        when "size"         then cls.size = attr.children[0].content.to_u64
        when "content-type" then cls.content_type = attr.children[0].content
        else
          # Ignore unknown attributes.
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["filename"] = filename unless filename.blank?
      dict["size"] = size.to_s
      dict["content-type"] = content_type unless content_type.blank?

      xml.element(@@xml_name.local, dict)
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # Header is a name/value pair the upload service requires the client to send
  # with the PUT (e.g. an Authorization bearer token).
  class Header
    class_getter xml_name : String = "header"
    property name : String = ""
    property value : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "name"  then cls.name = attr.children[0].content
        when "value" then cls.value = attr.children[0].content
        end
      end
      cls.value = node.content if cls.value.blank? && !node.content.blank?
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name, {"name" => name}) { xml.text value unless value.blank? }
    end
  end

  # Slot is the result of a slot request: temporary PUT and GET URLs granted
  # by the upload service, plus any headers the PUT must include.
  class Slot < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_HTTP_UPLOAD, "slot")
    property put_url : String = ""
    property get_url : String = ""
    property put_headers : Array(Header) = Array(Header).new

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
      node.children.select(&.element?).each do |child|
        case child.name
        when "put"
          cls.put_url = child.attributes["url"]?.try(&.content) || ""
          child.children.select(&.element?).each do |header|
            cls.put_headers << Header.new(header)
          end
        when "get"
          cls.get_url = child.attributes["url"]?.try(&.content) || ""
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.element("put", {"url" => put_url}) do
          put_headers.each &.to_xml xml
        end unless put_url.blank?
        xml.element("get", {"url" => get_url}) unless get_url.blank?
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_HTTP_UPLOAD, "request"), UploadRequest)
  Registry.map_extension(PacketType::IQ, XMLName.new(NS_HTTP_UPLOAD, "slot"), Slot)
end
