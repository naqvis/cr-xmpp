require "./spec_helper"
require "../src/xmpp/stanza/message/replace"
require "../src/xmpp/stanza"

private class CorrectionStubClient < XMPP::Client
  getter sent : Array(XMPP::Stanza::Message) = [] of XMPP::Stanza::Message

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def send(message : XMPP::Stanza::Message)
    @sent << message
  end
end

describe XMPP::Stanza::Replace do
  it "parses a replace payload carrying the corrected message id" do
    replace = XMPP::Stanza::Replace.new(
      "<replace id='f6d9f2a8-8d0a-4a5e-b1e6-4c2f6d5a1b3c' xmlns='urn:xmpp:message-correct:0'/>"
    )
    replace.id.should eq "f6d9f2a8-8d0a-4a5e-b1e6-4c2f6d5a1b3c"
  end

  it "serializes a replace payload" do
    replace = XMPP::Stanza::Replace.new
    replace.id = "abc-123"

    xml = XML.build { |x| replace.to_xml(x) }
    xml.should contain("urn:xmpp:message-correct:0")
    xml.should contain("id=\"abc-123\"")
  end

  it "is decoded from a message body" do
    message = XMPP::Stanza::Message.new(
      <<-XML
        <message type='chat' to='juliet@capulet.lit'>
          <body>My pardon</body>
          <replace id='abc-123' xmlns='urn:xmpp:message-correct:0'/>
        </message>
        XML
    )

    replace = message.get(XMPP::Stanza::Replace).as(XMPP::Stanza::Replace)
    replace.id.should eq "abc-123"
  end
end

describe XMPP::MessageCorrection do
  it "correct sends a message with the replace payload and new body" do
    client = CorrectionStubClient.new

    XMPP::MessageCorrection.new(client).correct(
      to: "juliet@capulet.lit", original_id: "abc-123", body: "My pardon"
    )

    message = client.sent.first
    message.to.should eq "juliet@capulet.lit"
    message.type.should eq "chat"
    message.body.should eq "My pardon"
    replace = message.get(XMPP::Stanza::Replace).as(XMPP::Stanza::Replace)
    replace.id.should eq "abc-123"
  end

  it "corrected? returns the corrected id for a correction" do
    client = CorrectionStubClient.new
    corrector = XMPP::MessageCorrection.new(client)

    message = XMPP::Stanza::Message.new
    replace = XMPP::Stanza::Replace.new
    replace.id = "abc-123"
    message.extensions << replace

    corrector.corrected?(message).should eq "abc-123"
  end

  it "corrected? returns nil for a plain message" do
    client = CorrectionStubClient.new
    corrector = XMPP::MessageCorrection.new(client)

    message = XMPP::Stanza::Message.new
    message.body = "Just a message"

    corrector.corrected?(message).should be_nil
  end
end
