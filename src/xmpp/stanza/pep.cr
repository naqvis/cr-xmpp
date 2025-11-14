require "./registry"
require "../stanza"

module XMPP::Stanza
  class Tune < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/tune", "tune")
    property artist : String = ""
    property length : Int32 = 0
    property rating : Int32 = 0
    property source : String = ""
    property title : String = ""
    property track : String = ""
    property uri : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "artist" then pr.artist = child.content
        when "length" then pr.length = child.content.to_i32
        when "rating" then pr.rating = child.content.to_i32
        when "source" then pr.source = child.content
        when "title"  then pr.title = child.content
        when "track"  then pr.track = child.content
        when "uri"    then pr.uri = child.content
        else
          # shouldn't be the case, but for any changes just ignore it.
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.element("artist") { xml.text artist } unless artist.blank?
        xml.element("length") { xml.text length.to_s } unless length == 0
        xml.element("rating") { xml.text rating.to_s } unless rating == 0
        xml.element("source") { xml.text source } unless source.blank?
        xml.element("title") { xml.text title } unless title.blank?
        xml.element("track") { xml.text track } unless track.blank?
        xml.element("uri") { xml.text uri } unless uri.blank?
      end
    end

    def name : String
      @@xml_name.local
    end
  end

  # Mood defines deta model for XEP-0107 - User Mood
  # See: https://xmpp.org/extensions/xep-0107.html
  class Mood < MsgExtension
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/mood", "mood")
    # TODO: Custom parsing to extract mood type from tag name.
    # Note: the list is predefined.
    property value : String = ""
    property text : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "text" then pr.text = child.content
        else
          pr.value = child.name
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.element(value) unless value.blank?
        xml.element("text") { xml.text text } unless text.blank?
      end
    end

    def name : String
      @@xml_name.local
    end
  end
end
