require "./registry"
require "../stanza"

module XMPP::Stanza
  NS_BOOKMARKS = "storage:bookmarks"

  # Bookmarks implements XEP-0048 - Bookmark Conformance.
  #
  # Bookmarks are the user's saved chat rooms (and URLs in v1.0). They are
  # conventionally stored on the PEP node "storage:bookmarks" (XEP-0402) and
  # may also be carried in private XML storage (XEP-0049). Items published to
  # the PEP node use this payload.
  class Bookmarks
    class_getter xml_name : String = "bookmarks"
    getter conferences : Array(BookmarkConference)
    getter urls : Array(BookmarkURL)

    def initialize
      @conferences = Array(BookmarkConference).new
      @urls = Array(BookmarkURL).new
    end

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
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless node.name == @@xml_name
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "conference" then pr.conferences << BookmarkConference.new(child)
        when "url"        then pr.urls << BookmarkURL.new(child)
        end
      end
      pr
    end

    # from_node converts a generic Item payload (as delivered in a PEP
    # notification) back into a Bookmarks model.
    def self.from_node(node : Node) : Bookmarks?
      xml = node.to_xml
      root = XML.parse(xml).first_element_child
      root ? new(root) : nil
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name, xmlns: NS_BOOKMARKS) do
        conferences.each &.to_xml xml
        urls.each &.to_xml xml
      end
    end

    # to_node converts the model into the generic Item payload used when
    # publishing to the "storage:bookmarks" PEP node.
    def to_node : Node
      xml_string = XML.build { |x| to_xml(x) }
      Node.new(XML.parse(xml_string).first_element_child.not_nil!)
    end
  end

  # BookmarkConference is one saved chat room.
  class BookmarkConference
    class_getter xml_name : String = "conference"
    property name : String = ""
    property autojoin : Bool = false
    property jid : String = ""
    property nick : String = ""
    property password : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "name"     then cls.name = attr.children[0].content
        when "autojoin" then cls.autojoin = attr.children[0].content == "true" || attr.children[0].content == "1"
        when "jid"      then cls.jid = attr.children[0].content
        when "password" then cls.password = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        cls.nick = child.content if child.name == "nick"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["name"] = name unless name.blank?
      dict["autojoin"] = "true" if autojoin
      dict["jid"] = jid unless jid.blank?
      dict["password"] = password unless password.blank?
      xml.element(@@xml_name, dict) do
        xml.element("nick") { xml.text nick } unless nick.blank?
      end
    end
  end

  # BookmarkURL is one saved URL (XEP-0048 v1.0).
  class BookmarkURL
    class_getter xml_name : String = "url"
    property name : String = ""
    property url : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "name" then cls.name = attr.children[0].content
        when "url"  then cls.url = attr.children[0].content
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["name"] = name unless name.blank?
      dict["url"] = url unless url.blank?
      xml.element(@@xml_name, dict)
    end
  end
end
