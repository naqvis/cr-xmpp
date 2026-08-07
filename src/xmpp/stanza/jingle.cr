require "./registry"
require "../stanza"

module XMPP::Stanza
  NS_JINGLE     = "urn:xmpp:jingle:1"
  NS_JINGLE_FT  = "urn:xmpp:jingle:apps:filetransfer:5"
  NS_JINGLE_IBB = "urn:xmpp:jingle:apps:ibb:1"

  # Jingle implements the core session stanza of XEP-0166. It wraps one or
  # more Content elements, each carrying a transport and/or an application
  # description (such as JingleFileTransfer or JingleIBB). Only the data model
  # for building and parsing offers/accepts is provided here.
  class Jingle < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_JINGLE, "jingle")
    property action : String = ""
    property initiator : String = ""
    property responder : String = ""
    property sid : String = ""
    getter contents : Array(Content) = Array(Content).new

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
        when "action"    then cls.action = attr.children[0].content
        when "initiator" then cls.initiator = attr.children[0].content
        when "responder" then cls.responder = attr.children[0].content
        when "sid"       then cls.sid = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        cls.contents << Content.new(child) if child.name == "content"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["action"] = action unless action.blank?
      dict["initiator"] = initiator unless initiator.blank?
      dict["responder"] = responder unless responder.blank?
      dict["sid"] = sid unless sid.blank?
      xml.element(@@xml_name.local, dict) do
        contents.each &.to_xml xml
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # Content is one <content/> of a Jingle session.
  class Content
    class_getter xml_name : String = "content"
    property creator : String = ""
    property disposition : String = ""
    property name : String = ""
    property description : JingleDescription? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "creator"     then cls.creator = attr.children[0].content
        when "disposition" then cls.disposition = attr.children[0].content
        when "name"        then cls.name = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "description"
          case child.namespace.try &.href
          when NS_JINGLE_FT  then cls.description = JingleFileTransfer.new(child)
          when NS_JINGLE_IBB then cls.description = JingleIBB.new(child)
          end
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["creator"] = creator unless creator.blank?
      dict["disposition"] = disposition unless disposition.blank?
      dict["name"] = name unless name.blank?
      xml.element(@@xml_name, dict) do
        description.try &.to_xml xml
      end
    end
  end

  # JingleDescription is the abstract base of Jingle application descriptions.
  abstract class JingleDescription
    abstract def to_xml(xml : XML::Builder)
  end

  # JingleFileTransfer implements the application description of XEP-0234 -
  # Jingle File Transfer. A description carries one File offer.
  class JingleFileTransfer < JingleDescription
    class_getter xml_name : XMLName = XMLName.new(NS_JINGLE_FT, "description")
    property offer : Bool = false
    property file : JingleFile? = nil

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == NS_JINGLE_FT) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "offer"
          cls.offer = true
          child.children.select(&.element?).each do |offer_child|
            cls.file = JingleFile.new(offer_child) if offer_child.name == "file"
          end
        when "file"
          cls.file = JingleFile.new(child)
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        if offer
          xml.element("offer") { file.try &.to_xml xml }
        else
          file.try &.to_xml xml
        end
      end
    end
  end

  # JingleFile is the <file/> metadata of a file transfer: name, size, date,
  # description, and an optional SHA-1 hash.
  class JingleFile
    class_getter xml_name : String = "file"
    property name : String = ""
    property size : Int64 = 0
    property date : String = ""
    property desc : String = ""
    property hash : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "name" then cls.name = child.content
        when "size" then cls.size = child.content.to_i64
        when "date" then cls.date = child.content
        when "desc" then cls.desc = child.content
        when "hash" then cls.hash = child.content
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name) do
        xml.element("name") { xml.text name } unless name.blank?
        xml.element("size") { xml.text size.to_s } unless size == 0
        xml.element("date") { xml.text date } unless date.blank?
        xml.element("desc") { xml.text desc } unless desc.blank?
        unless hash.blank?
          xml.element("hash", xmlns: "urn:xmpp:hashes:1", algo: "sha-1") { xml.text hash }
        end
      end
    end
  end

  # JingleIBB implements the application description of XEP-0261 - Jingle
  # In-Band Bytestreams. It negotiates the maximum block size for the
  # underlying XEP-0047 stream.
  class JingleIBB < JingleDescription
    class_getter xml_name : XMLName = XMLName.new(NS_JINGLE_IBB, "description")
    property block_size : Int32 = 0

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == NS_JINGLE_IBB) &&
                                                                        (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        cls.block_size = child.content.to_i32 if child.name == "block-size"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.element("block-size") { xml.text block_size.to_s } unless block_size == 0
      end
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_JINGLE, "jingle"), Jingle)
end
