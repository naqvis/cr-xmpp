require "./spec_helper"

describe XMPP::Me do
  it "body wraps text in the /me prefix" do
    XMPP::Me.body("dances a jig").should eq "/me dances a jig"
  end

  it "display replaces the prefix with the identity" do
    XMPP::Me.display("Juliet", "/me dances a jig").should eq "* Juliet dances a jig"
  end

  it "display returns non-/me bodies unchanged" do
    XMPP::Me.display("Juliet", "hello world").should eq "hello world"
  end
end

describe XMPP::Stanza::Message do
  it "detects a /me command body" do
    message = XMPP::Stanza::Message.new
    message.body = "/me dances a jig"
    message.me?.should be_true
    message.me_body.should eq "dances a jig"
  end

  it "treats a plain body as not a /me command" do
    message = XMPP::Stanza::Message.new
    message.body = "hello world"
    message.me?.should be_false
    message.me_body.should eq "hello world"
  end

  it "requires the space after the prefix" do
    message = XMPP::Stanza::Message.new
    message.body = "/medley"
    message.me?.should be_false
  end

  it "formats a display string" do
    message = XMPP::Stanza::Message.new
    message.body = "/me dances a jig"
    message.me_display("Juliet").should eq "* Juliet dances a jig"
  end
end
