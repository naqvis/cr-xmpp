require "../spec_helper"

module XMPP::Stanza
  it "Test No Start TLS" do
    xml = <<-X
    <stream:features xmlns:stream='http://etherx.jabber.org/streams'></stream:features>
    X
    parsed_sf = StreamFeatures.new xml
    tls, ok = parsed_sf.does_start_tls
    fail "StartTLS feature should not be enabled" if ok
    fail "StartTLS cannot be required as default" if tls.required?
  end

  it "Test StartTLS" do
    xml = <<-X
    <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
  <starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'>
    <required/>
  </starttls>
</stream:features>
X
    parsed_sf = StreamFeatures.new xml

    tls, ok = parsed_sf.does_start_tls
    fail "StartTLS feature should be enabled" unless ok
    fail "StartTLS feature should be required" unless tls.required?
  end

  it "Test Stream Management" do
    xml = <<-X
    <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
    <sm xmlns='urn:xmpp:sm:3'/>
</stream:features>
X

    parsed_sf = StreamFeatures.new xml
    fail "Stream Management feature should have been detected" unless parsed_sf.does_stream_management
  end
end
