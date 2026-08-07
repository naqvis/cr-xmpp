require "../registry"
require "../../xmpp"

module XMPP::Stanza
  NS_VCARD_TEMP = "vcard-temp"

  # XEP-0054: vcard-temp.
  #
  # The vCard data model for temporary vCard data, exchanged as an IQ payload
  # against a user's bare JID. Supports the common textual fields (FN,
  # NICKNAME, BDAY, URL, NOTE) plus the structured N, ORG and PHOTO elements
  # and EMAIL/TEL collections.
  class VCard < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new(NS_VCARD_TEMP, "vCard")
    property fn : String = ""
    property nickname : String = ""
    property bday : String = ""
    property url : String = ""
    property note : String = ""
    property n : N? = nil
    property org : Org? = nil
    property photo : Photo? = nil
    property emails : Array(Email) = Array(Email).new
    property tels : Array(Telephone) = Array(Telephone).new

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
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "FN"       then pr.fn = child.content
        when "NICKNAME" then pr.nickname = child.content
        when "BDAY"     then pr.bday = child.content
        when "URL"      then pr.url = child.content
        when "NOTE"     then pr.note = child.content
        when "N"        then pr.n = N.new(child)
        when "ORG"      then pr.org = Org.new(child)
        when "PHOTO"    then pr.photo = Photo.new(child)
        when "EMAIL"    then pr.emails << Email.new(child)
        when "TEL"      then pr.tels << Telephone.new(child)
        else
          # Ignore unknown vCard elements.
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.element("FN") { xml.text fn } unless fn.blank?
        xml.element("NICKNAME") { xml.text nickname } unless nickname.blank?
        n.try &.to_xml xml
        xml.element("BDAY") { xml.text bday } unless bday.blank?
        xml.element("URL") { xml.text url } unless url.blank?
        org.try &.to_xml xml
        emails.each &.to_xml xml
        tels.each &.to_xml xml
        photo.try &.to_xml xml
        xml.element("NOTE") { xml.text note } unless note.blank?
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # Name information (N).
  class N
    class_getter xml_name : String = "N"
    property family : String = ""
    property given : String = ""
    property middle : String = ""
    property prefix : String = ""
    property suffix : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "FAMILY" then cls.family = child.content
        when "GIVEN"  then cls.given = child.content
        when "MIDDLE" then cls.middle = child.content
        when "PREFIX" then cls.prefix = child.content
        when "SUFFIX" then cls.suffix = child.content
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name) do
        xml.element("FAMILY") { xml.text family } unless family.blank?
        xml.element("GIVEN") { xml.text given } unless given.blank?
        xml.element("MIDDLE") { xml.text middle } unless middle.blank?
        xml.element("PREFIX") { xml.text prefix } unless prefix.blank?
        xml.element("SUFFIX") { xml.text suffix } unless suffix.blank?
      end
    end
  end

  # Organization information (ORG).
  class Org
    class_getter xml_name : String = "ORG"
    property name : String = ""
    property units : Array(String) = Array(String).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "ORGNAME" then cls.name = child.content
        when "ORGUNIT" then cls.units << child.content
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name) do
        xml.element("ORGNAME") { xml.text name } unless name.blank?
        units.each { |unit| xml.element("ORGUNIT") { xml.text unit } unless unit.blank? }
      end
    end
  end

  # vCard photo (PHOTO) carrying a base64-encoded BINVAL, used for vCard-based
  # avatars (XEP-0153) and read from vCard data by XEP-0398 implementations.
  class Photo
    class_getter xml_name : String = "PHOTO"
    property type : String = ""
    property binval : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "TYPE"   then cls.type = child.content
        when "BINVAL" then cls.binval = child.content
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name) do
        xml.element("TYPE") { xml.text type } unless type.blank?
        xml.element("BINVAL") { xml.text binval } unless binval.blank?
      end
    end
  end

  # Email address (EMAIL). typing holds the flags expressed as child elements
  # (e.g. WORK, INTERNET, PREF), userid is the actual address.
  class Email
    class_getter xml_name : String = "EMAIL"
    property typing : Array(String) = Array(String).new
    property userid : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.children.select(&.element?).each do |child|
        cls.typing << child.name unless child.name == "USERID"
        cls.userid = child.content if child.name == "USERID"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name) do
        typing.each { |flag| xml.element(flag) }
        xml.element("USERID") { xml.text userid } unless userid.blank?
      end
    end
  end

  # Telephone number (TEL). typing holds the flags (e.g. WORK, VOICE), number
  # is the actual dial string.
  class Telephone
    class_getter xml_name : String = "TEL"
    property typing : Array(String) = Array(String).new
    property number : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.children.select(&.element?).each do |child|
        cls.typing << child.name unless child.name == "NUMBER"
        cls.number = child.content if child.name == "NUMBER"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name) do
        typing.each { |flag| xml.element(flag) }
        xml.element("NUMBER") { xml.text number } unless number.blank?
      end
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new(NS_VCARD_TEMP, "vCard"), VCard)
end
