require "../spec_helper"

module XMPP::Stanza
  it "Test Unmarshalling IQs" do
    str = "<iq id=\"1\" type=\"set\" to=\"test@localhost\"/>"
    iq = IQ.new
    iq.type = IQ_TYPE_SET
    iq.to = "test@localhost"
    iq.id = "1"

    parsed_iq = IQ.new str

    parsed_iq.to_xml.should eq(iq.to_xml)
  end

  it "Test Generate IQ" do
    iq = IQ.new
    iq.type = IQ_TYPE_RESULT
    iq.from = "admin@localhost"
    iq.to = "test@localhost"
    iq.id = "1"

    payload = DiscoInfo.new
    payload.add_identity("Test Gateway", "gateway", "mqtt")
    payload.add_features([XMPP::Stanza::NS_DISCO_INFO, NS_DISCO_ITEMS])

    iq.payload = payload

    xml = iq.to_xml
    xml.should_not contain("<error") # empty error should not be serialized

    parsed_iq = IQ.new xml

    got = iq.payload.try &.to_xml
    want = parsed_iq.payload.try &.to_xml
    got.should eq(want)
  end

  it "Test Error Tag" do
    err = Error.new
    err.code = 503
    err.type = ERROR_CANCEL
    err.reason = "service-unavailable"
    err.text = "User session not found"

    xml = err.to_xml
    parsed = Error.new xml
    xml.should eq(parsed.to_xml)
  end

  it "Test DiscoItems" do
    iq = IQ.new
    iq.type = IQ_TYPE_GET
    iq.from = "romeo@montague.net/orchard"
    iq.to = "catalog.shakespeare.lit"
    iq.id = "items3"
    payload = DiscoItems.new
    payload.node = "music"
    iq.payload = payload

    xml = iq.to_xml

    parsed_iq = IQ.new xml
    xml.should eq(parsed_iq.to_xml)

    got = iq.payload.try &.to_xml
    want = parsed_iq.payload.try &.to_xml
    got.should eq(want)
  end

  it "Test Unmarshalling Payload" do
    query = "<iq to='service.localhost' type='get' id='1'><query xmlns='jabber:iq:version'/></iq>"
    iq = IQ.new query
    fail "Missing payload" if iq.payload.nil?

    ns = iq.payload.try &.as(IQPayload).namespace
    ns.should eq("jabber:iq:version")
  end

  it "Test payload with error" do
    xml = <<-XML
   <iq xml:lang='en' to='test1@localhost/resource' from='test@localhost' type='error' id='aac1a'>
 <query xmlns='jabber:iq:version'/>
 <error code='407' type='auth'>
  <subscription-required xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
  <text xml:lang='en' xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'>Not subscribed</text>
 </error>
</iq>
XML
    iq = IQ.new xml
    iq.error.try &.reason.should eq("subscription-required")
  end

  it "Test Unknown payload" do
    xml = <<-XML
    <iq type="get" to="service.localhost" id="1" >
    <query xmlns="unknown:ns"/>
   </iq>
XML
    iq = IQ.new xml
    fail "Missing Any" if iq.any.nil?
    iq.any.try &.namespace.should eq("unknown:ns")
  end
end
