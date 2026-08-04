require "./spec_helper"
require "../src/xmpp/stanza/pep_event"

describe XMPP::Stanza::PubSubEvent do
  describe "parsing" do
    it "parses a tune notification event" do
      xml = <<-XML
        <message from='hamlet@denmark.lit/castle' to='horatio@denmark.lit/room'>
          <event xmlns='http://jabber.org/protocol/pubsub#event'>
            <items node='http://jabber.org/protocol/tune'>
              <item>
                <tune xmlns='http://jabber.org/protocol/tune'>
                  <artist>The Beatles</artist>
                  <title>Hey Jude</title>
                </tune>
              </item>
            </items>
          </event>
        </message>
      XML

      msg = XMPP::Stanza::Message.new(xml)
      event = msg.get(XMPP::Stanza::PubSubEvent).as(XMPP::Stanza::PubSubEvent?)
      ev = event.not_nil!
      items = ev.items.not_nil!
      items.node.should eq("http://jabber.org/protocol/tune")
      items.items.size.should eq(1)
      item = items.items[0]
      item.tune.should_not be_nil
      item.tune.not_nil!.artist.should eq("The Beatles")
      item.tune.not_nil!.title.should eq("Hey Jude")
    end

    it "parses an event without items" do
      xml = <<-XML
        <message from='hamlet@denmark.lit/castle' to='horatio@denmark.lit/room'>
          <event xmlns='http://jabber.org/protocol/pubsub#event'>
            <items node='http://jabber.org/protocol/tune'/>
          </event>
        </message>
      XML

      msg = XMPP::Stanza::Message.new(xml)
      ev = msg.get(XMPP::Stanza::PubSubEvent).as(XMPP::Stanza::PubSubEvent).not_nil!
      ev.items.not_nil!.items.size.should eq(0)
    end

    it "parses a retract event" do
      xml = <<-XML
        <message from='hamlet@denmark.lit/castle' to='horatio@denmark.lit/room'>
          <event xmlns='http://jabber.org/protocol/pubsub#event'>
            <retract node='http://jabber.org/protocol/tune'>
              <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
            </retract>
          </event>
        </message>
      XML

      msg = XMPP::Stanza::Message.new(xml)
      ev = msg.get(XMPP::Stanza::PubSubEvent).as(XMPP::Stanza::PubSubEvent).not_nil!
      ev.items.should be_nil
      retract = ev.retract.not_nil!
      retract.node.should eq("http://jabber.org/protocol/tune")
      retract.item.not_nil!.id.should eq("ae890ac52d0df67ed7cfdf51b644e901")
    end
  end

  describe "serialization" do
    it "round-trips items" do
      event = XMPP::Stanza::PubSubEvent.new
      items = XMPP::Stanza::Items.new
      items.node = "http://jabber.org/protocol/mood"
      item = XMPP::Stanza::Item.new
      item.id = "current"
      mood = XMPP::Stanza::Mood.new
      mood.value = "happy"
      item.mood = mood
      items.items << item
      event.items = items

      xml = XML.build { |x| event.to_xml(x) }
      xml.should contain("xmlns=\"http://jabber.org/protocol/pubsub#event\"")
      xml.should contain("node=\"http://jabber.org/protocol/mood\"")
      xml.should contain("happy")
    end
  end
end
