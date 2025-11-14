require "../spec_helper"

module XMPP::Stanza
  it "Test Control Set" do
    xml = <<-XML
    <iq to='test@localhost/jukebox' from='admin@localhost/mbp' type='set' id='2'>
 <set xmlns='urn:xmpp:iot:control' xml:lang='en'>
	<string name='action' value='play'/>
	<string name='url' value='https://soundcloud.com/radiohead/spectre'/>
 </set>
</iq>
XML
    iq = IQ.new xml
    if payload = iq.payload
      payload.as(ControlSet)
    else
      fail "No payload found. Expected ControlSet payload, but found none"
    end
  end
end
