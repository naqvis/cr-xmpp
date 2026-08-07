require "./spec_helper"
require "../src/xmpp/stanza/bookmarks"
require "../src/xmpp/stanza"

private class BookmarksStubClient < XMPP::Client
  getter sent : Array(XMPP::Stanza::IQ) = [] of XMPP::Stanza::IQ

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def send(stanza : XMPP::Stanza::IQ)
    @sent << stanza
  end
end

describe XMPP::Stanza::Bookmarks do
  it "parses a bookmarks payload with conferences and urls" do
    bookmarks = XMPP::Stanza::Bookmarks.new(<<-XML)
      <bookmarks xmlns='storage:bookmarks'>
        <conference name='Design' autojoin='true' jid='design@conference.example.org'>
          <nick>juliet</nick>
        </conference>
        <conference name='Support' jid='support@conference.example.org'/>
        <url name='Docs' url='https://docs.example.org'/>
      </bookmarks>
      XML

    bookmarks.conferences.size.should eq 2
    design = bookmarks.conferences[0]
    design.name.should eq "Design"
    design.autojoin.should be_true
    design.jid.should eq "design@conference.example.org"
    design.nick.should eq "juliet"
    bookmarks.conferences[1].autojoin.should be_false
    url = bookmarks.urls.first
    url.name.should eq "Docs"
    url.url.should eq "https://docs.example.org"
  end

  it "serializes a bookmarks payload" do
    bookmarks = XMPP::Stanza::Bookmarks.new
    room = XMPP::Stanza::BookmarkConference.new
    room.name = "Design"
    room.jid = "design@conference.example.org"
    room.autojoin = true
    bookmarks.conferences << room

    xml = XML.build { |x| bookmarks.to_xml(x) }
    xml.should contain("storage:bookmarks")
    xml.should contain("<conference name=\"Design\" autojoin=\"true\" jid=\"design@conference.example.org\"/>")
  end

  it "round-trips through the generic node model" do
    bookmarks = XMPP::Stanza::Bookmarks.new
    room = XMPP::Stanza::BookmarkConference.new
    room.name = "Design"
    room.jid = "design@conference.example.org"
    bookmarks.conferences << room

    node = bookmarks.to_node
    restored = XMPP::Stanza::Bookmarks.from_node(node)

    restored.should_not be_nil
    restored.not_nil!.conferences.size.should eq 1
    restored.not_nil!.conferences.first.jid.should eq "design@conference.example.org"
  end
end

describe XMPP::Bookmarks do
  it "publish sends a PEP set to the storage:bookmarks node" do
    client = BookmarksStubClient.new
    bookmarks = XMPP::Stanza::Bookmarks.new
    room = XMPP::Stanza::BookmarkConference.new
    room.name = "Design"
    room.jid = "design@conference.example.org"
    bookmarks.conferences << room

    XMPP::Bookmarks.new(client).publish(bookmarks)

    iq = client.sent.first
    iq.type.should eq "set"
    iq.to.should eq ""
    pubsub = iq.payload.as(XMPP::Stanza::PubSub)
    publish = pubsub.publish.not_nil!
    publish.node.should eq "storage:bookmarks"
    publish.item.not_nil!.id.should eq "current"
    publish.item.not_nil!.extra.should_not be_nil
  end

  it "from_message extracts bookmarks from a PEP notification" do
    message = XMPP::Stanza::Message.new(<<-XML)
      <message from='juliet@capulet.lit' to='romeo@montague.lit'>
        <event xmlns='http://jabber.org/protocol/pubsub#event'>
          <items node='storage:bookmarks'>
            <item id='current'>
              <bookmarks xmlns='storage:bookmarks'>
                <conference name='Design' jid='design@conference.example.org'/>
              </bookmarks>
            </item>
          </items>
        </event>
      </message>
      XML

    bookmarks = XMPP::Bookmarks.from_message(message)

    bookmarks.should_not be_nil
    bookmarks.not_nil!.conferences.first.jid.should eq "design@conference.example.org"
  end

  it "from_message returns nil for a non-bookmark notification" do
    message = XMPP::Stanza::Message.new(<<-XML)
      <message from='juliet@capulet.lit' to='romeo@montague.lit'>
        <event xmlns='http://jabber.org/protocol/pubsub#event'>
          <items node='urn:xmpp:avatar:metadata'>
            <item id='abc'><metadata xmlns='urn:xmpp:avatar:metadata'/></item>
          </items>
        </event>
      </message>
      XML

    XMPP::Bookmarks.from_message(message).should be_nil
  end

  it "from_message returns nil for a plain message" do
    message = XMPP::Stanza::Message.new
    message.body = "hi"

    XMPP::Bookmarks.from_message(message).should be_nil
  end
end
