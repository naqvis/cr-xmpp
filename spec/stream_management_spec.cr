require "./spec_helper"

describe "Stream Management" do
  describe XMPP::SMState do
    it "initializes with default values" do
      state = XMPP::SMState.new

      state.id.should eq ""
      state.inbound.should eq 0_u32
      state.location.should eq ""
      state.max.should eq 0_u32
      state.error.should eq ""
      state.timestamp.should be_a(Time)
    end

    it "initializes with custom values" do
      timestamp = Time.utc(2024, 1, 1, 12, 0, 0)
      state = XMPP::SMState.new(
        id: "test-id",
        inbound: 42_u32,
        location: "server1.example.com",
        max: 300_u32,
        timestamp: timestamp,
        error: "test error"
      )

      state.id.should eq "test-id"
      state.inbound.should eq 42_u32
      state.location.should eq "server1.example.com"
      state.max.should eq 300_u32
      state.timestamp.should eq timestamp
      state.error.should eq "test error"
    end

    describe "#resumption_expired?" do
      it "returns false when max is 0 (no expiration)" do
        state = XMPP::SMState.new(id: "test", max: 0_u32)
        state.resumption_expired?.should be_false
      end

      it "returns false when within max time" do
        state = XMPP::SMState.new(
          id: "test",
          max: 300_u32,
          timestamp: Time.utc - 100.seconds
        )
        state.resumption_expired?.should be_false
      end

      it "returns true when max time exceeded" do
        state = XMPP::SMState.new(
          id: "test",
          max: 300_u32,
          timestamp: Time.utc - 400.seconds
        )
        state.resumption_expired?.should be_true
      end

      it "returns true when exactly at max time" do
        state = XMPP::SMState.new(
          id: "test",
          max: 300_u32,
          timestamp: Time.utc - 301.seconds
        )
        # Should be expired (> max)
        state.resumption_expired?.should be_true
      end
    end

    describe "#can_resume?" do
      it "returns false when id is blank" do
        state = XMPP::SMState.new(id: "", max: 300_u32)
        state.can_resume?.should be_false
      end

      it "returns false when resumption expired" do
        state = XMPP::SMState.new(
          id: "test",
          max: 300_u32,
          timestamp: Time.utc - 400.seconds
        )
        state.can_resume?.should be_false
      end

      it "returns true when id present and not expired" do
        state = XMPP::SMState.new(
          id: "test",
          max: 300_u32,
          timestamp: Time.utc - 100.seconds
        )
        state.can_resume?.should be_true
      end

      it "returns true when id present and no expiration set" do
        state = XMPP::SMState.new(id: "test", max: 0_u32)
        state.can_resume?.should be_true
      end
    end

    describe "#touch" do
      it "updates timestamp to current time" do
        old_time = Time.utc - 100.seconds
        state = XMPP::SMState.new(timestamp: old_time)

        state.touch

        # Timestamp should be updated (within 1 second of now)
        (Time.utc - state.timestamp).total_seconds.should be < 1.0
        state.timestamp.should_not eq old_time
      end
    end
  end

  describe XMPP::Stanza::SMFailed do
    it "parses failed without error cause" do
      xml = <<-XML
        <failed xmlns='urn:xmpp:sm:3'/>
      XML

      failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)

      failed.error_type.should eq ""
      failed.cause.should be_nil
    end

    it "parses failed with item-not-found error" do
      xml = <<-XML
        <failed xmlns='urn:xmpp:sm:3'>
          <item-not-found xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
        </failed>
      XML

      failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)

      failed.error_type.should eq "item-not-found"
      failed.cause.should_not be_nil
    end

    it "parses failed with unexpected-request error" do
      xml = <<-XML
        <failed xmlns='urn:xmpp:sm:3'>
          <unexpected-request xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
        </failed>
      XML

      failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)

      failed.error_type.should eq "unexpected-request"
    end

    describe "#error_description" do
      it "returns description for item-not-found" do
        xml = <<-XML
          <failed xmlns='urn:xmpp:sm:3'>
            <item-not-found xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
          </failed>
        XML

        failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)
        failed.error_description.should eq "Session not found or expired"
      end

      it "returns description for unexpected-request" do
        xml = <<-XML
          <failed xmlns='urn:xmpp:sm:3'>
            <unexpected-request xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
          </failed>
        XML

        failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)
        failed.error_description.should eq "Stream management request was unexpected"
      end

      it "returns description for feature-not-implemented" do
        xml = <<-XML
          <failed xmlns='urn:xmpp:sm:3'>
            <feature-not-implemented xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
          </failed>
        XML

        failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)
        failed.error_description.should eq "Stream management feature not implemented"
      end

      it "returns description for service-unavailable" do
        xml = <<-XML
          <failed xmlns='urn:xmpp:sm:3'>
            <service-unavailable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
          </failed>
        XML

        failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)
        failed.error_description.should eq "Stream management service unavailable"
      end

      it "returns error type for unknown errors" do
        xml = <<-XML
          <failed xmlns='urn:xmpp:sm:3'>
            <custom-error xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
          </failed>
        XML

        failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)
        failed.error_description.should eq "custom-error"
      end

      it "returns 'Unknown error' when no error type" do
        xml = <<-XML
          <failed xmlns='urn:xmpp:sm:3'/>
        XML

        failed = XMPP::Stanza::SMFailed.new(XML.parse(xml).first_element_child.not_nil!)
        failed.error_description.should eq "Unknown error"
      end
    end

    it "serializes to XML correctly" do
      failed = XMPP::Stanza::SMFailed.new
      xml = failed.to_xml

      xml.should contain("<failed")
      xml.should contain("xmlns=\"urn:xmpp:sm:3\"")
    end
  end

  describe XMPP::Stanza::SMEnabled do
    it "parses enabled with all attributes" do
      xml = <<-XML
        <enabled xmlns='urn:xmpp:sm:3'
                 id='session-123'
                 location='server1.example.com'
                 resume='true'
                 max='300'/>
      XML

      enabled = XMPP::Stanza::SMEnabled.new(XML.parse(xml).first_element_child.not_nil!)

      enabled.id.should eq "session-123"
      enabled.location.should eq "server1.example.com"
      enabled.resume.should eq "true"
      enabled.max.should eq 300_u32
    end

    it "parses enabled with minimal attributes" do
      xml = <<-XML
        <enabled xmlns='urn:xmpp:sm:3' id='session-456'/>
      XML

      enabled = XMPP::Stanza::SMEnabled.new(XML.parse(xml).first_element_child.not_nil!)

      enabled.id.should eq "session-456"
      enabled.location.should eq ""
      enabled.resume.should eq ""
      enabled.max.should eq 0_u32
    end
  end
end
