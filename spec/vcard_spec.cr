require "./spec_helper"
require "../src/xmpp/stanza/iq/vcard"

private class VCardStubClient < XMPP::Client
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

describe XMPP::Stanza::VCard do
  it "parses a vCard with structured and textual fields" do
    vcard = XMPP::Stanza::VCard.new(<<-XML)
      <vCard xmlns='vcard-temp'>
        <FN>Juliet Capulet</FN>
        <NICKNAME>Jules</NICKNAME>
        <N><FAMILY>Capulet</FAMILY><GIVEN>Juliet</GIVEN><PREFIX>Lady</PREFIX></N>
        <BDAY>1579-07-31</BDAY>
        <ORG><ORGNAME>Capulets</ORGNAME><ORGUNIT>Household</ORGUNIT></ORG>
        <EMAIL><WORK/><INTERNET/><PREF/><USERID>juliet@capulet.lit</USERID></EMAIL>
        <TEL><WORK/><VOICE/><NUMBER>+44 20 7946 0958</NUMBER></TEL>
        <URL>https://capulet.lit/juliet</URL>
      </vCard>
      XML

    vcard.fn.should eq "Juliet Capulet"
    vcard.nickname.should eq "Jules"
    n = vcard.n.should_not be_nil
    n.family.should eq "Capulet"
    n.given.should eq "Juliet"
    n.prefix.should eq "Lady"
    vcard.bday.should eq "1579-07-31"
    org = vcard.org.should_not be_nil
    org.name.should eq "Capulets"
    org.units.should eq ["Household"]
    email = vcard.emails.first
    email.userid.should eq "juliet@capulet.lit"
    email.typing.should eq ["WORK", "INTERNET", "PREF"]
    tel = vcard.tels.first
    tel.number.should eq "+44 20 7946 0958"
    tel.typing.should eq ["WORK", "VOICE"]
    vcard.url.should eq "https://capulet.lit/juliet"
  end

  it "parses a vCard photo" do
    vcard = XMPP::Stanza::VCard.new(<<-XML)
      <vCard xmlns='vcard-temp'>
        <PHOTO><TYPE>image/jpeg</TYPE><BINVAL>YWJj</BINVAL></PHOTO>
      </vCard>
      XML

    photo = vcard.photo.should_not be_nil
    photo.type.should eq "image/jpeg"
    photo.binval.should eq "YWJj"
  end

  it "serializes a vCard" do
    vcard = XMPP::Stanza::VCard.new
    vcard.fn = "Romeo Montague"
    vcard.n = XMPP::Stanza::N.new.tap { |n| n.family = "Montague"; n.given = "Romeo" }
    email = XMPP::Stanza::Email.new
    email.userid = "romeo@example.org"
    email.typing = ["HOME", "INTERNET"]
    vcard.emails << email

    xml = XML.build { |x| vcard.to_xml(x) }
    xml.should contain("vCard")
    xml.should contain("xmlns=\"vcard-temp\"")
    xml.should contain("<FN>Romeo Montague</FN>")
    xml.should contain("<FAMILY>Montague</FAMILY>")
    xml.should contain("<USERID>romeo@example.org</USERID>")
    xml.should contain("<INTERNET/>")
  end
end

describe XMPP::VCard do
  it "fetch sends an IQ-get to the bare JID and returns the vCard payload" do
    client = VCardStubClient.new
    source = XMPP::Stanza::VCard.new
    source.fn = "Juliet Capulet"
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = source
    client.response = result

    card = XMPP::VCard.new(client).fetch

    card.should_not be_nil
    card.not_nil!.fn.should eq "Juliet Capulet"
    iq = client.requested.first
    iq.type.should eq "get"
    iq.to.should eq "test@localhost"
    iq.payload.should be_a(XMPP::Stanza::VCard)
  end

  it "fetch returns nil on an error result" do
    client = VCardStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "error"
    client.response = result

    XMPP::VCard.new(client).fetch.should be_nil
  end

  it "set sends an IQ-set and returns the response" do
    client = VCardStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    vcard = XMPP::Stanza::VCard.new
    vcard.fn = "Romeo"
    response = XMPP::VCard.new(client).set(vcard)

    response.should be result
    iq = client.requested.first
    iq.type.should eq "set"
    iq.to.should eq "test@localhost"
    iq.payload.should be vcard
  end
end
