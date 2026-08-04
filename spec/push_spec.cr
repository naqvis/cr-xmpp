require "./spec_helper"

private class StubClient < XMPP::Client
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

describe XMPP::Push do
  it "enable sends an IQ-set to the bare JID and returns the result" do
    client = StubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    response = XMPP::Push.new(client).enable("push-5.client.example", "yxs32uqsflafdk3iuqo")

    response.should be result
    iq = client.requested.first
    iq.type.should eq "set"
    iq.to.should eq "test@localhost"
    payload = iq.payload.as(XMPP::Stanza::PushEnable)
    payload.jid.should eq "push-5.client.example"
    payload.node.should eq "yxs32uqsflafdk3iuqo"
  end

  it "disable sends an IQ-set to the bare JID without a node" do
    client = StubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    response = XMPP::Push.new(client).disable("push-5.client.example")

    response.should be result
    iq = client.requested.first
    iq.type.should eq "set"
    iq.to.should eq "test@localhost"
    payload = iq.payload.as(XMPP::Stanza::PushDisable)
    payload.jid.should eq "push-5.client.example"
    payload.node.should eq ""
  end

  it "disable includes an optional node when given" do
    client = StubClient.new
    client.response = XMPP::Stanza::IQ.new

    XMPP::Push.new(client).disable("push-5.client.example", "yxs32uqsflafdk3iuqo")

    payload = client.requested.first.payload.as(XMPP::Stanza::PushDisable)
    payload.node.should eq "yxs32uqsflafdk3iuqo"
  end

  it "supported? is true when disco advertises urn:xmpp:push:0" do
    client = StubClient.new
    info = XMPP::Stanza::DiscoInfo.new
    feature = XMPP::Stanza::Feature.new
    feature.var = "urn:xmpp:push:0"
    info.features << feature
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = info
    client.response = result

    XMPP::Push.new(client).supported?.should be_true
  end

  it "supported? is false when disco lacks the feature" do
    client = StubClient.new
    info = XMPP::Stanza::DiscoInfo.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = info
    client.response = result

    XMPP::Push.new(client).supported?.should be_false
  end
end
