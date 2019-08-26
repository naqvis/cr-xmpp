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
        end
      end
      pr
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element("artist") { elem.text artist } unless artist.blank?
        elem.element("length") { elem.text length.to_s } unless length == 0
        elem.element("rating") { elem.text rating.to_s } unless rating == 0
        elem.element("source") { elem.text source } unless source.blank?
        elem.element("title") { elem.text title } unless title.blank?
        elem.element("track") { elem.text track } unless track.blank?
        elem.element("uri") { elem.text uri } unless uri.blank?
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

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element(value) unless value.blank?
        elem.element("text") { elem.text text } unless text.blank?
      end
    end

    def name : String
      @@xml_name.local
    end
  end
end
