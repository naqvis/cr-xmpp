require "../../spec_helper"

module XMPP::Stanza
  it "Test Decode Request" do
    xml = <<-XML
        <message
            from='northumberland@shakespeare.lit/westminster'
            id='richard2-4.1.247'
            to='kingrichard@royalty.england.lit/throne'>
        <body>My lord, dispatch; read o'er these articles.</body>
        <request xmlns='urn:xmpp:receipts'/>
        </message>
        XML

    parsed_msg = Message.new xml
    parsed_msg.body.should eq ("My lord, dispatch; read o'er these articles.")

    fail "no extension found on parsed message" unless parsed_msg.extensions.size > 0

    ext = parsed_msg.extensions[0]
    fail "could not find receipts extension" unless ext.is_a?(ReceiptRequest)
  end
end
