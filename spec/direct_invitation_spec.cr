require "./spec_helper"
require "../src/xmpp/stanza/message/direct_invite"

private class DirectInviteStubClient < XMPP::Client
  getter sent : Array(String) = [] of String

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def send(packet : String)
    @sent << packet
    packet
  end
end

describe XMPP::Stanza::DirectInvite do
  it "parses an invitation" do
    invite = XMPP::Stanza::DirectInvite.new(<<-XML)
      <x xmlns='jabber:x:conference'
         jid='darkcave@chat.example.net'
         password='cavern'
         reason='Join us!'
         continue='true'/>
      XML

    invite.jid.should eq "darkcave@chat.example.net"
    invite.password.should eq "cavern"
    invite.reason.should eq "Join us!"
    invite.continue?.should be_true
  end

  it "serializes an invitation" do
    invite = XMPP::Stanza::DirectInvite.new
    invite.jid = "courtyard@example.org"
    invite.reason = "Hello there"
    invite.continue = true

    xml = XML.build { |x| invite.to_xml(x) }
    xml.should contain("jabber:x:conference")
    xml.should contain("jid=\"courtyard@example.org\"")
    xml.should contain("reason=\"Hello there\"")
    xml.should contain("continue=\"true\"")
  end

  it "omits optional attributes when unset" do
    invite = XMPP::Stanza::DirectInvite.new
    invite.jid = "courtyard@example.org"

    xml = XML.build { |x| invite.to_xml(x) }
    xml.should_not contain("password")
    xml.should_not contain("continue")
  end
end

describe XMPP::DirectInvitation do
  it "sends a message carrying the invite" do
    client = DirectInviteStubClient.new

    XMPP::DirectInvitation.new(client)
      .invite("romeo@example.org", "courtyard@example.org", reason: "Hello")

    xml = client.sent.first
    xml.should contain("to=\"romeo@example.org\"")
    xml.should contain("jabber:x:conference")
    xml.should contain("jid=\"courtyard@example.org\"")
    xml.should contain("reason=\"Hello\"")
  end
end
