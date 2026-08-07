require "./spec_helper"
require "../src/xmpp/stanza/presence/pubsub_event"
require "../src/xmpp/stanza"

describe XMPP::PEPNotifications do
  it "from_message extracts the pubsub#event payload" do
    message = XMPP::Stanza::Message.new(<<-XML)
      <message from='juliet@capulet.lit' to='romeo@montague.lit'>
        <event xmlns='http://jabber.org/protocol/pubsub#event'>
          <items node='urn:xmpp:avatar:metadata'/>
        </event>
      </message>
      XML

    event = XMPP::PEPNotifications.from_message(message)
    event.should_not be_nil
    event.not_nil!.items.not_nil!.node.should eq "urn:xmpp:avatar:metadata"
  end

  it "from_presence extracts the presence-carried pubsub#event payload" do
    presence = XMPP::Stanza::Presence.new(<<-XML)
      <presence from='juliet@capulet.lit' to='romeo@montague.lit'>
        <x xmlns='http://jabber.org/protocol/pubsub#event'>
          <items node='urn:xmpp:avatar:metadata'>
            <item id='abc'>
              <metadata xmlns='urn:xmpp:avatar:metadata'/>
            </item>
          </items>
        </x>
      </presence>
      XML

    event = XMPP::PEPNotifications.from_presence(presence)

    event.should_not be_nil
    items = event.not_nil!.items.not_nil!
    items.node.should eq "urn:xmpp:avatar:metadata"
    items.items.size.should eq 1
    items.items.first.id.should eq "abc"
  end

  it "from_presence returns nil for plain presence" do
    presence = XMPP::Stanza::Presence.new
    presence.type = "unavailable"

    XMPP::PEPNotifications.from_presence(presence).should be_nil
  end

  it "from_stanza dispatches on message or presence" do
    message = XMPP::Stanza::Message.new(<<-XML)
      <message><event xmlns='http://jabber.org/protocol/pubsub#event'>
        <items node='http://jabber.org/protocol/tune'/>
      </event></message>
      XML
    presence = XMPP::Stanza::Presence.new(<<-XML)
      <presence><x xmlns='http://jabber.org/protocol/pubsub#event'>
        <items node='http://jabber.org/protocol/tune'/>
      </x></presence>
      XML

    XMPP::PEPNotifications.from_stanza(message).should_not be_nil
    XMPP::PEPNotifications.from_stanza(presence).should_not be_nil
    XMPP::PEPNotifications.from_stanza(XMPP::Stanza::Message.new).should be_nil
  end
end
