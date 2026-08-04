require "../spec_helper"

describe XMPP::Stanza::PushEnable do
  it "serializes jid and node attributes" do
    payload = XMPP::Stanza::PushEnable.new
    payload.jid = "push-5.client.example"
    payload.node = "yxs32uqsflafdk3iuqo"
    payload.to_xml.should eq %(<enable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo"/>\n)
  end

  it "round-trips attributes through XML" do
    payload = XMPP::Stanza::PushEnable.new
    payload.jid = "push-5.client.example"
    payload.node = "yxs32uqsflafdk3iuqo"
    reparsed = XMPP::Stanza::PushEnable.new(XML.parse(payload.to_xml).first_element_child.not_nil!)
    reparsed.jid.should eq "push-5.client.example"
    reparsed.node.should eq "yxs32uqsflafdk3iuqo"
  end

  it "preserves unknown child elements" do
    xml = <<-XML
      <enable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo">
        <x xmlns="jabber:x:data" type="submit"/>
      </enable>
    XML
    payload = XMPP::Stanza::PushEnable.new(XML.parse(xml).first_element_child.not_nil!)
    payload.any.size.should eq 1
    payload.any.first.name.should eq "x"
  end

  it "resolves from the IQ registry" do
    iq = XMPP::Stanza::IQ.new(%(<iq type="set" to="test@localhost"><enable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo"/></iq>))
    payload = iq.payload.as(XMPP::Stanza::PushEnable)
    payload.jid.should eq "push-5.client.example"
    payload.node.should eq "yxs32uqsflafdk3iuqo"
  end
end

describe XMPP::Stanza::PushDisable do
  it "serializes jid without node" do
    payload = XMPP::Stanza::PushDisable.new
    payload.jid = "push-5.client.example"
    payload.to_xml.should eq %(<disable xmlns="urn:xmpp:push:0" jid="push-5.client.example"/>\n)
  end

  it "serializes jid with an optional node" do
    payload = XMPP::Stanza::PushDisable.new
    payload.jid = "push-5.client.example"
    payload.node = "yxs32uqsflafdk3iuqo"
    payload.to_xml.should eq %(<disable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo"/>\n)
  end

  it "round-trips attributes through XML" do
    payload = XMPP::Stanza::PushDisable.new
    payload.jid = "push-5.client.example"
    payload.node = "yxs32uqsflafdk3iuqo"
    reparsed = XMPP::Stanza::PushDisable.new(XML.parse(payload.to_xml).first_element_child.not_nil!)
    reparsed.jid.should eq "push-5.client.example"
    reparsed.node.should eq "yxs32uqsflafdk3iuqo"
  end

  it "resolves from the IQ registry" do
    iq = XMPP::Stanza::IQ.new(%(<iq type="set" to="test@localhost"><disable xmlns="urn:xmpp:push:0" jid="push-5.client.example"/></iq>))
    payload = iq.payload.as(XMPP::Stanza::PushDisable)
    payload.jid.should eq "push-5.client.example"
  end
end
