require "../spec_helper"

module XMPP::Stanza
  it "Test Generate Message" do
    msg = Message.new
    msg.type = MESSAGE_TYPE_CHAT
    msg.from = "admin@localhost"
    msg.to = "test@localhost"
    msg.id = "1"
    msg.body = "Hi"
    msg.subject = "Msg Subject"

    xml = msg.to_xml

    parsed_msg = Message.new xml

    xml.should eq(parsed_msg.to_xml)
  end

  it "Test Decode Error" do
    xml = <<-XML
    <message from='juliet@capulet.com'
         id='msg_1'
         to='romeo@montague.lit'
         type='error'>
  <error type='cancel'>
    <not-acceptable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
  </error>
</message>
XML

    msg = Message.new xml
    if type = msg.error.try &.type
      type.should eq("cancel")
    else
      fail "Unable to parse Error XML"
    end
  end

  it "Test Get OOB" do
    image = "https://localhost/image.png"
    msg = Message.new
    msg.to = "test@localhost"
    ext = OOB.new
    ext.url = image
    msg.extensions << ext

    # OOB can properly be found
    # Try to find
    oob = msg.get(OOB)
    fail "could not find oob extension" if oob.nil?
    oob.as(OOB).url.should eq(image)

    # Markable is not found
    m = msg.get(Markable)
    fail "we should not have found markable extension" unless m.nil?
  end
end
