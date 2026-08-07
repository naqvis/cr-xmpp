require "./spec_helper"
require "../src/xmpp/stanza/carbons"

private class CarbonsStubClient < XMPP::Client
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

describe XMPP::Stanza::CarbonSent do
  it "parses a sent carbon and unwraps the forwarded message" do
    sent = XMPP::Stanza::CarbonSent.new(<<-XML)
      <sent xmlns='urn:xmpp:carbons:2'>
        <forwarded xmlns='urn:xmpp:forward:0'>
          <message xmlns='jabber:client' from='juliet@capulet.lit/balcony'
                   to='romeo@montague.net/orchard' type='chat'>
            <body>Art thou gone?</body>
          </message>
        </forwarded>
      </sent>
      XML

    forwarded = sent.forwarded.should_not be_nil
    stanza = forwarded.stanza
    stanza.should be_a(XMPP::Stanza::Message)
    message = stanza.as(XMPP::Stanza::Message)
    message.body.should eq "Art thou gone?"
    message.from.should eq "juliet@capulet.lit/balcony"
  end
end

describe XMPP::Stanza::CarbonReceived do
  it "parses a received carbon" do
    received = XMPP::Stanza::CarbonReceived.new(<<-XML)
      <received xmlns='urn:xmpp:carbons:2'>
        <forwarded xmlns='urn:xmpp:forward:0'>
          <message xmlns='jabber:client' from='romeo@montague.net/orchard'
                   to='juliet@capulet.lit/balcony' type='chat'>
            <body>Wherefore?</body>
          </message>
        </forwarded>
      </received>
      XML

    forwarded = received.forwarded.should_not be_nil
    stanza = forwarded.stanza
    stanza.should be_a(XMPP::Stanza::Message)
    message = stanza.as(XMPP::Stanza::Message)
    message.body.should eq "Wherefore?"
  end

  it "serializes a carbon payload" do
    received = XMPP::Stanza::CarbonReceived.new
    original = XMPP::Stanza::Message.new
    original.from = "juliet@capulet.lit/balcony"
    original.type = "chat"
    original.body = "Good night"
    forwarded = XMPP::Stanza::Forwarded.new
    forwarded.stanza = original
    received.forwarded = forwarded

    xml = XML.build { |x| received.to_xml(x) }
    xml.should contain("urn:xmpp:carbons:2")
    xml.should contain("urn:xmpp:forward:0")
    xml.should contain("Good night")
  end
end

describe XMPP::Carbons do
  it "enable sends an IQ-set to the bare JID" do
    client = CarbonsStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    response = XMPP::Carbons.new(client).enable

    response.should be result
    iq = client.requested.first
    iq.type.should eq "set"
    iq.to.should eq "test@localhost"
    iq.payload.should be_a(XMPP::Stanza::CarbonsEnable)
  end

  it "disable sends an IQ-set to the bare JID" do
    client = CarbonsStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    response = XMPP::Carbons.new(client).disable

    response.should be result
    iq = client.requested.first
    iq.type.should eq "set"
    iq.payload.should be_a(XMPP::Stanza::CarbonsDisable)
  end

  it "supported? is true when disco advertises urn:xmpp:carbons:2" do
    client = CarbonsStubClient.new
    info = XMPP::Stanza::DiscoInfo.new
    feature = XMPP::Stanza::Feature.new
    feature.var = "urn:xmpp:carbons:2"
    info.features << feature
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = info
    client.response = result

    XMPP::Carbons.new(client).supported?.should be_true
    client.requested.first.to.should eq "localhost"
  end

  it "supported? is false when disco lacks the feature" do
    client = CarbonsStubClient.new
    info = XMPP::Stanza::DiscoInfo.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = info
    client.response = result

    XMPP::Carbons.new(client).supported?.should be_false
  end
end
