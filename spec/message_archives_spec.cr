require "./spec_helper"
require "../src/xmpp/stanza/iq/mam"
require "../src/xmpp/stanza/message/mam_result"

private class MamStubClient < XMPP::Client
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

describe XMPP::Stanza::MAMQuery do
  it "parses a query with form filters and rsm paging" do
    query = XMPP::Stanza::MAMQuery.new(<<-XML)
      <query xmlns='urn:xmpp:mam:2' queryid='f27'>
        <x xmlns='jabber:x:data' type='submit'>
          <field var='FORM_TYPE' type='hidden'><value>urn:xmpp:mam:2</value></field>
          <field var='with'><value>juliet@capulet.lit</value></field>
        </x>
        <set xmlns='http://jabber.org/protocol/rsm'>
          <max>10</max>
        </set>
      </query>
      XML

    query.queryid.should eq "f27"
    query.with_jid.should eq "juliet@capulet.lit"
    query.max.should eq 10
  end

  it "serializes a query with filters and paging" do
    query = XMPP::Stanza::MAMQuery.new
    query.queryid = "f27"
    query.with_jid = "juliet@capulet.lit"
    query.max = 10
    query.after = "09af3-cc343-b409f"

    xml = XML.build { |x| query.to_xml(x) }
    xml.should contain("urn:xmpp:mam:2")
    xml.should contain("queryid=\"f27\"")
    xml.should contain("jabber:x:data")
    xml.should contain("<field var=\"with\"><value>juliet@capulet.lit</value></field>")
    xml.should contain("<max>10</max>")
    xml.should contain("<after>09af3-cc343-b409f</after>")
  end
end

describe XMPP::Stanza::MAMFin do
  it "parses a complete fin" do
    fin = XMPP::Stanza::MAMFin.new(
      "<fin xmlns='urn:xmpp:mam:2' complete='true'/>"
    )
    fin.complete.should be_true
    fin.stable.should be_true
  end

  it "parses an incomplete fin" do
    fin = XMPP::Stanza::MAMFin.new(
      "<fin xmlns='urn:xmpp:mam:2' stable='false'/>"
    )
    fin.complete.should be_false
    fin.stable.should be_false
  end
end

describe XMPP::Stanza::MAMResult do
  it "parses a result wrapping a forwarded message" do
    result = XMPP::Stanza::MAMResult.new(<<-XML)
      <result xmlns='urn:xmpp:mam:2' queryid='f27' id='28482-98726-73623'>
        <forwarded xmlns='urn:xmpp:forward:0'>
          <delay xmlns='urn:xmpp:delay' stamp='2010-07-10T23:08:25Z'/>
          <message from='juliet@capulet.lit' to='romeo@montague.lit' type='chat'>
            <body>O Romeo, Romeo!</body>
          </message>
        </forwarded>
      </result>
      XML

    result.queryid.should eq "f27"
    result.id.should eq "28482-98726-73623"
    forwarded = result.forwarded.should_not be_nil
    stanza = forwarded.not_nil!.stanza.as(XMPP::Stanza::Message)
    stanza.body.should eq "O Romeo, Romeo!"
    stanza.from.should eq "juliet@capulet.lit"
  end
end

describe XMPP::MessageArchives do
  it "supported? is true when disco advertises urn:xmpp:mam:2" do
    client = MamStubClient.new
    info = XMPP::Stanza::DiscoInfo.new
    feature = XMPP::Stanza::Feature.new
    feature.var = "urn:xmpp:mam:2"
    info.features << feature
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = info
    client.response = result

    XMPP::MessageArchives.new(client).supported?.should be_true
  end

  it "query sends an IQ-set and returns the fin payload" do
    client = MamStubClient.new
    fin = XMPP::Stanza::MAMFin.new
    fin.complete = true
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = fin
    client.response = result

    response_fin = XMPP::MessageArchives.new(client).query(
      with_jid: "juliet@capulet.lit", limit: 10, queryid: "f27"
    )

    response_fin.should be fin
    iq = client.requested.first
    iq.type.should eq "set"
    iq.to.should eq "test@localhost"
    query = iq.payload.as(XMPP::Stanza::MAMQuery)
    query.queryid.should eq "f27"
    query.with_jid.should eq "juliet@capulet.lit"
    query.max.should eq 10
  end

  it "query returns nil on an error result" do
    client = MamStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "error"
    client.response = result

    XMPP::MessageArchives.new(client).query.should be_nil
  end
end
