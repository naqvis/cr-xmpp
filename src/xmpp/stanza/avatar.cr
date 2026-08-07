require "./registry"
require "../stanza"

module XMPP::Stanza
  NS_AVATAR_DATA     = "urn:xmpp:avatar:data"
  NS_AVATAR_METADATA = "urn:xmpp:avatar:metadata"

  # AvatarData is the payload of the "urn:xmpp:avatar:data" PEP node
  # (XEP-0084). It holds the base64-encoded avatar image bytes.
  class AvatarData
    class_getter xml_name : String = "data"
    property data : String = ""

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
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == NS_AVATAR_DATA) &&
                                                                        (node.name == @@xml_name)
      cls = new()
      cls.data = node.content
      cls
    end

    # from_node converts a generic Item payload (as delivered in a PEP
    # notification) back into an AvatarData model.
    def self.from_node(node : Node) : AvatarData?
      xml = node.to_xml
      root = XML.parse(xml).first_element_child
      root ? new(root) : nil
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name, xmlns: NS_AVATAR_DATA) { xml.text data }
    end

    def to_node : Node
      xml_string = XML.build { |x| to_xml(x) }
      Node.new(XML.parse(xml_string).first_element_child.not_nil!)
    end
  end

  # AvatarMetadata is the payload of the "urn:xmpp:avatar:metadata" PEP node
  # (XEP-0084). It describes the published avatar without the image bytes so
  # subscribers can decide whether to fetch the data node.
  class AvatarMetadata
    class_getter xml_name : String = "metadata"
    getter infos : Array(AvatarInfo) = Array(AvatarInfo).new

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
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == NS_AVATAR_METADATA) &&
                                                                        (node.name == @@xml_name)
      pr = new()
      node.children.select(&.element?).each do |child|
        pr.infos << AvatarInfo.new(child) if child.name == "info"
      end
      pr
    end

    # from_node converts a generic Item payload (as delivered in a PEP
    # notification) back into an AvatarMetadata model.
    def self.from_node(node : Node) : AvatarMetadata?
      xml = node.to_xml
      root = XML.parse(xml).first_element_child
      root ? new(root) : nil
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name, xmlns: NS_AVATAR_METADATA) do
        infos.each &.to_xml xml
      end
    end

    def to_node : Node
      xml_string = XML.build { |x| to_xml(x) }
      Node.new(XML.parse(xml_string).first_element_child.not_nil!)
    end
  end

  # AvatarInfo describes one avatar format within metadata: the id hashes the
  # image, type is the MIME type, bytes is the image size in bytes.
  class AvatarInfo
    class_getter xml_name : String = "info"
    property id : String = ""
    property type : String = ""
    property bytes : Int32 = 0
    property height : Int32 = 0
    property width : Int32 = 0

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "id"     then cls.id = attr.children[0].content
        when "type"   then cls.type = attr.children[0].content
        when "bytes"  then cls.bytes = attr.children[0].content.to_i32
        when "height" then cls.height = attr.children[0].content.to_i32
        when "width"  then cls.width = attr.children[0].content.to_i32
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["id"] = id unless id.blank?
      dict["type"] = type unless type.blank?
      dict["bytes"] = bytes.to_s unless bytes == 0
      dict["height"] = height.to_s unless height == 0
      dict["width"] = width.to_s unless width == 0
      xml.element(@@xml_name, dict)
    end
  end
end
