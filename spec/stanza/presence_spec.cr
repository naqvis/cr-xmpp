require "../spec_helper"

module XMPP::Stanza
  it "Test Generate Presence" do
    msg = Presence.new
    msg.type = PRESENCE_SHOW_CHAT
    msg.from = "admin@localhost"
    msg.to = "test@localhost"
    msg.id = "1"

    xml = msg.to_xml
    parsed_msg = Presence.new xml
    xml.should eq(parsed_msg.to_xml)
  end

  it "Test Presence Sub Elements" do
    msg = Presence.new
    msg.type = PRESENCE_SHOW_CHAT
    msg.from = "admin@localhost"
    msg.to = "test@localhost"
    msg.id = "1"
    msg.show = PRESENCE_SHOW_XA
    msg.status = "Coding"
    msg.priority = 10
    xml = msg.to_xml

    parsed_pres = Pres.new xml

    parsed_pres.show.should eq(msg.show)
    parsed_pres.status.should eq(msg.status)
    parsed_pres.priority.should eq(msg.priority)
  end

  # Test struct to ensure that show, status, and priority are
  # correctly defined as presence package sub-elements
  private struct Pres
    property show : String = ""
    property status : String = ""
    property priority : Int8 = 0_i8

    def initialize
    end

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
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "show"     then cls.show = child.content
        when "status"   then cls.status = child.content
        when "priority" then cls.priority = child.content.to_i8
        end
      end
      cls
    end
  end
end
