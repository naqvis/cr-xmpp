require "../../spec_helper"

module XMPP::Stanza
  it "Test HTML Generation" do
    html_body = "<p>Hello <b>World</b></p>"
    msg = Message.new
    msg.to = "test@localhost"
    msg.body = "Hello World"
    body = HTMLBody.new
    body.inner_xml = html_body
    html = HTML.new
    html.body = body

    msg.extensions << html
    result = msg.xmpp_format
    str = <<-X
    <?xml version="1.0"?>\n<message to="test@localhost"><body>Hello World</body><html xmlns="http://jabber.org/protocol/xhtml-im"><body xmlns="http://www.w3.org/1999/xhtml"><p>Hello <b>World</b></p></body></html></message>\n
    X
    result.should eq(str)

    parsed_msg = Message.new str
    parsed_msg.body.should eq(msg.body)

    h = parsed_msg.get(HTML)
    fail "could not extract HTML body" if h.nil?

    h.as(HTML).body.try &.inner_xml.should eq(html_body)
  end
end
