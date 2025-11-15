require "./spec_helper"

describe "XEP-0114: Jabber Component Protocol - Error Handling" do
  describe XMPP::ComponentConflictError do
    it "creates error with default message" do
      error = XMPP::ComponentConflictError.new

      error.message.should eq "Component JID is already connected"
    end

    it "creates error with custom message" do
      error = XMPP::ComponentConflictError.new("Custom conflict message")

      error.message.should eq "Custom conflict message"
    end
  end

  describe XMPP::ComponentHostUnknownError do
    it "creates error with host information" do
      error = XMPP::ComponentHostUnknownError.new("gateway.example.com")

      msg = error.message
      msg.should_not be_nil
      if msg
        msg.should contain("gateway.example.com")
        msg.should contain("not recognized")
      end
    end
  end

  describe XMPP::ComponentAuthenticationError do
    it "creates error with default message" do
      error = XMPP::ComponentAuthenticationError.new

      error.message.should eq "Component authentication failed"
    end

    it "creates error with custom message" do
      error = XMPP::ComponentAuthenticationError.new("Invalid secret")

      error.message.should eq "Invalid secret"
    end
  end

  describe XMPP::ComponentInvalidNamespaceError do
    it "creates error with default message" do
      error = XMPP::ComponentInvalidNamespaceError.new

      error.message.should eq "Invalid namespace in component stream"
    end
  end

  describe XMPP::ComponentStreamError do
    it "creates error with type and message" do
      error = XMPP::ComponentStreamError.new("policy-violation", "Rate limit exceeded")

      error.error_type.should eq "policy-violation"
      error.message.should eq "Rate limit exceeded"
    end

    it "creates error with type only" do
      error = XMPP::ComponentStreamError.new("internal-server-error")

      error.error_type.should eq "internal-server-error"
      msg = error.message
      msg.should_not be_nil
      if msg
        msg.should contain("internal-server-error")
      end
    end
  end

  describe "Stream Error Parsing" do
    it "parses conflict error" do
      xml = <<-XML
        <stream:error xmlns:stream='http://etherx.jabber.org/streams'>
          <conflict xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
          <text xmlns='urn:ietf:params:xml:ns:xmpp-streams'>Component already connected</text>
        </stream:error>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      error = XMPP::Stanza::StreamError.new(node)

      error.error.should_not be_nil
      if err = error.error
        err.xml_name.local.should eq "conflict"
      end
      error.text.strip.should contain("already connected")
    end

    it "parses host-unknown error" do
      xml = <<-XML
        <stream:error xmlns:stream='http://etherx.jabber.org/streams'>
          <host-unknown xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
          <text xmlns='urn:ietf:params:xml:ns:xmpp-streams'>Unknown host: gateway.example.com</text>
        </stream:error>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      error = XMPP::Stanza::StreamError.new(node)

      error.error.should_not be_nil
      if err = error.error
        err.xml_name.local.should eq "host-unknown"
      end
      error.text.strip.should contain("Unknown host")
    end

    it "parses not-authorized error" do
      xml = <<-XML
        <stream:error xmlns:stream='http://etherx.jabber.org/streams'>
          <not-authorized xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
          <text xmlns='urn:ietf:params:xml:ns:xmpp-streams'>Invalid component secret</text>
        </stream:error>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      error = XMPP::Stanza::StreamError.new(node)

      error.error.should_not be_nil
      if err = error.error
        err.xml_name.local.should eq "not-authorized"
      end
      error.text.strip.should contain("Invalid component secret")
    end

    it "parses invalid-namespace error" do
      xml = <<-XML
        <stream:error xmlns:stream='http://etherx.jabber.org/streams'>
          <invalid-namespace xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
        </stream:error>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      error = XMPP::Stanza::StreamError.new(node)

      error.error.should_not be_nil
      if err = error.error
        err.xml_name.local.should eq "invalid-namespace"
      end
    end

    it "parses generic stream error" do
      xml = <<-XML
        <stream:error xmlns:stream='http://etherx.jabber.org/streams'>
          <internal-server-error xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
          <text xmlns='urn:ietf:params:xml:ns:xmpp-streams'>Server error occurred</text>
        </stream:error>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      error = XMPP::Stanza::StreamError.new(node)

      error.error.should_not be_nil
      if err = error.error
        err.xml_name.local.should eq "internal-server-error"
      end
      error.text.strip.should eq "Server error occurred"
    end
  end
end
