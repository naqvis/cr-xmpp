require "./spec_helper"

describe "connection error taxonomy" do
  it "classifies transient transport and TLS negotiation failures as retryable" do
    XMPP::ConnectionClosed.new("closed").retryable?.should be_true
    XMPP::TLSNegotiationError.new("handshake interrupted").retryable?.should be_true
  end

  it "classifies credentials, verification, protocol, and component policy failures as permanent" do
    XMPP::AuthenticationError.new("bad credentials").retryable?.should be_false
    XMPP::TLSVerificationError.new("wrong certificate").retryable?.should be_false
    XMPP::StreamParseError.new("malformed XML").retryable?.should be_false
    XMPP::StreamManagementError.new("invalid acknowledgement").retryable?.should be_false
    XMPP::ComponentAuthenticationError.new.retryable?.should be_false
    XMPP::ComponentConflictError.new.retryable?.should be_false
  end
end

describe XMPP::Stanza::Parser do
  it "raises a typed parse error for an invalid stream opening" do
    node = XML.parse("<message xmlns='jabber:client'/>").first_element_child.not_nil!

    expect_raises(XMPP::Stanza::ParseError, /expected <stream>/) do
      XMPP::Stanza::Parser.init_stream(node)
    end
  end

  it "raises a typed parse error for an unknown top-level namespace" do
    node = XML.parse("<example xmlns='urn:example:unknown'/>").first_element_child.not_nil!

    expect_raises(XMPP::Stanza::ParseError, /unknown namespace/) do
      XMPP::Stanza::Parser.next_packet(node)
    end
  end

  it "raises a typed parse error for an unknown stream-management nonza" do
    node = XML.parse("<unknown xmlns='urn:xmpp:sm:3'/>").first_element_child.not_nil!

    expect_raises(XMPP::Stanza::ParseError, /unexpected XMPP packet/) do
      XMPP::Stanza::Parser.next_packet(node)
    end
  end
end
