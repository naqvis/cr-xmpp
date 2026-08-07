require "./spec_helper"
require "../src/xmpp/stanza/iq/blocking"

private class BlockingStubClient < XMPP::Client
  getter requested : Array(XMPP::Stanza::IQ) = [] of XMPP::Stanza::IQ
  property response : XMPP::Stanza::IQ? = nil

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def request(iq : XMPP::Stanza::IQ, timeout : Time::Span = 5.seconds) : XMPP::Stanza::IQ?
    @requested << iq
    @response
  end

  def bare_jid : String
    "test@localhost"
  end
end

describe XMPP::Stanza::Blocklist do
  it "parses a blocklist of blocked items" do
    list = XMPP::Stanza::Blocklist.new(<<-XML)
      <blocklist xmlns='urn:xmpp:blocking'>
        <item jid='romeo@example.net'/>
        <item jid='iago@example.net'/>
      </blocklist>
      XML

    list.items.size.should eq 2
    list.items[0].jid.should eq "romeo@example.net"
    list.items[1].jid.should eq "iago@example.net"
  end

  it "serializes a block command" do
    block = XMPP::Stanza::Block.new
    block.items << XMPP::Stanza::BlockItem.new("romeo@example.net")

    xml = XML.build { |x| block.to_xml(x) }
    xml.should contain("urn:xmpp:blocking")
    xml.should contain("<item jid=\"romeo@example.net\"/>")
  end

  it "serializes an unblock command without items to clear the list" do
    unblock = XMPP::Stanza::Unblock.new

    xml = XML.build { |x| unblock.to_xml(x) }
    xml.should contain("<unblock xmlns=\"urn:xmpp:blocking\"/>")
  end
end

describe XMPP::Blocking do
  it "supported? is true when disco advertises urn:xmpp:blocking" do
    client = BlockingStubClient.new
    info = XMPP::Stanza::DiscoInfo.new
    feature = XMPP::Stanza::Feature.new
    feature.var = "urn:xmpp:blocking"
    info.features << feature
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = info
    client.response = result

    XMPP::Blocking.new(client).supported?.should be_true
  end

  it "list returns the blocked items from the response" do
    client = BlockingStubClient.new
    list = XMPP::Stanza::Blocklist.new
    list.items << XMPP::Stanza::BlockItem.new("romeo@example.net")
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = list
    client.response = result

    items = XMPP::Blocking.new(client).list
    items.should_not be_nil
    items.not_nil!.size.should eq 1

    iq = client.requested.first
    iq.type.should eq "get"
    iq.to.should eq "test@localhost"
    iq.payload.should be_a(XMPP::Stanza::Blocklist)
  end

  it "list returns nil on an error result" do
    client = BlockingStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "error"
    client.response = result

    XMPP::Blocking.new(client).list.should be_nil
  end

  it "block sends an IQ-set with the given jids" do
    client = BlockingStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    response = XMPP::Blocking.new(client).block(["romeo@example.net", "iago@example.net"])

    response.should be result
    iq = client.requested.first
    iq.type.should eq "set"
    iq.to.should eq "test@localhost"
    block = iq.payload.as(XMPP::Stanza::Block)
    block.items.map(&.jid).should eq ["romeo@example.net", "iago@example.net"]
  end

  it "unblock with no jids sends an empty unblock to clear the list" do
    client = BlockingStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    response = XMPP::Blocking.new(client).unblock

    response.should be result
    iq = client.requested.first
    iq.payload.should be_a(XMPP::Stanza::Unblock)
    iq.payload.as(XMPP::Stanza::Unblock).items.should be_empty
  end
end
