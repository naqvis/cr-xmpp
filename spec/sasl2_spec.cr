require "./spec_helper"

describe "XEP-0388: SASL2 (Extensible SASL Profile)" do
  describe "SASL2 Authentication in Stream Features" do
    it "parses SASL2 authentication from stream features" do
      xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>SCRAM-SHA-1</mechanism>
            <mechanism>SCRAM-SHA-256-PLUS</mechanism>
            <inline>
              <sm xmlns='urn:xmpp:sm:3'/>
              <bind xmlns='urn:xmpp:bind:0'/>
            </inline>
          </authentication>
        </stream:features>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      features = XMPP::Stanza::StreamFeatures.new(node)

      features.supports_sasl2?.should be_true
      sasl2 = features.sasl2_authentication
      sasl2.should_not be_nil

      if sasl2
        sasl2.mechanisms.should contain("SCRAM-SHA-1")
        sasl2.mechanisms.should contain("SCRAM-SHA-256-PLUS")
        sasl2.supports_mechanism?("SCRAM-SHA-1").should be_true
        sasl2.supports_mechanism?("PLAIN").should be_false
        sasl2.inline_features.size.should eq 2
        sasl2.supports_inline?("urn:xmpp:sm:3").should be_true
        sasl2.supports_inline?("urn:xmpp:bind:0").should be_true
      end
    end

    it "handles SASL2 without inline features" do
      xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>PLAIN</mechanism>
          </authentication>
        </stream:features>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      features = XMPP::Stanza::StreamFeatures.new(node)

      sasl2 = features.sasl2_authentication
      sasl2.should_not be_nil
      if sasl2
        sasl2.inline_features.should be_empty
      end
    end

    it "serializes SASL2 authentication correctly" do
      xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>SCRAM-SHA-256</mechanism>
            <inline>
              <sm xmlns='urn:xmpp:sm:3'/>
            </inline>
          </authentication>
        </stream:features>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      features = XMPP::Stanza::StreamFeatures.new(node)

      serialized = features.to_xml
      serialized.should contain("<authentication xmlns=\"urn:xmpp:sasl:2\">")
      serialized.should contain("<mechanism>SCRAM-SHA-256</mechanism>")
      serialized.should contain("<inline>")
    end
  end

  describe XMPP::Stanza::SASL2UserAgent do
    it "parses user-agent with all fields" do
      xml = <<-XML
        <user-agent id='d4565fa7-4d72-4749-b3d3-740edbf87770'>
          <software>AwesomeXMPP</software>
          <device>Kiva's Phone</device>
        </user-agent>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      ua = XMPP::Stanza::SASL2UserAgent.new(node)

      ua.id.should eq "d4565fa7-4d72-4749-b3d3-740edbf87770"
      ua.software.should eq "AwesomeXMPP"
      ua.device.should eq "Kiva's Phone"
    end

    it "handles optional fields" do
      xml = <<-XML
        <user-agent id='test-id'>
          <software>TestClient</software>
        </user-agent>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      ua = XMPP::Stanza::SASL2UserAgent.new(node)

      ua.id.should eq "test-id"
      ua.software.should eq "TestClient"
      ua.device.should be_empty
    end

    it "serializes user-agent correctly" do
      ua = XMPP::Stanza::SASL2UserAgent.new(
        id: "test-uuid",
        software: "Crystal-XMPP",
        device: "Test Device"
      )

      xml = String.build do |str|
        builder = XML::Builder.new(str)
        ua.to_xml(builder)
        builder.flush
      end

      xml.should contain("id=\"test-uuid\"")
      xml.should contain("<software>Crystal-XMPP</software>")
      xml.should contain("<device>Test Device</device>")
    end
  end

  describe XMPP::Stanza::SASL2Authenticate do
    it "parses authenticate with user-agent" do
      xml = <<-XML
        <authenticate xmlns='urn:xmpp:sasl:2' mechanism='SCRAM-SHA-256-PLUS'>
          <initial-response>cD10bHMtZXhwb3J0ZXI=</initial-response>
          <user-agent id='d4565fa7-4d72-4749-b3d3-740edbf87770'>
            <software>AwesomeXMPP</software>
            <device>Kiva's Phone</device>
          </user-agent>
        </authenticate>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      auth = XMPP::Stanza::SASL2Authenticate.new(node)

      auth.mechanism.should eq "SCRAM-SHA-256-PLUS"
      auth.initial_response.should eq "cD10bHMtZXhwb3J0ZXI="
      auth.user_agent.should_not be_nil
      if ua = auth.user_agent
        ua.id.should eq "d4565fa7-4d72-4749-b3d3-740edbf87770"
        ua.software.should eq "AwesomeXMPP"
      end
    end

    it "parses authenticate with upgrades" do
      xml = <<-XML
        <authenticate xmlns='urn:xmpp:sasl:2' mechanism='SCRAM-SHA-1'>
          <initial-response>biwsbj10ZXN0</initial-response>
          <user-agent id='test-id'>
            <software>TestClient</software>
          </user-agent>
          <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-256</upgrade>
          <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-512</upgrade>
        </authenticate>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      auth = XMPP::Stanza::SASL2Authenticate.new(node)

      auth.upgrades.size.should eq 2
      auth.upgrades.should contain("UPGR-SCRAM-SHA-256")
      auth.upgrades.should contain("UPGR-SCRAM-SHA-512")
    end

    it "serializes authenticate correctly" do
      ua = XMPP::Stanza::SASL2UserAgent.new(
        id: "test-uuid",
        software: "Crystal-XMPP"
      )

      auth = XMPP::Stanza::SASL2Authenticate.new(
        mechanism: "SCRAM-SHA-256",
        initial_response: "dGVzdA==",
        user_agent: ua,
        upgrades: ["UPGR-SCRAM-SHA-512"]
      )

      xml = auth.to_xml

      xml.should contain("mechanism=\"SCRAM-SHA-256\"")
      xml.should contain("<initial-response>dGVzdA==</initial-response>")
      xml.should contain("<user-agent")
      xml.should contain("<upgrade xmlns=\"urn:xmpp:sasl:upgrade:0\">UPGR-SCRAM-SHA-512</upgrade>")
    end
  end

  describe XMPP::Stanza::SASL2Challenge do
    it "parses challenge" do
      xml = <<-XML
        <challenge xmlns='urn:xmpp:sasl:2'>cj0xMkM0Q0Q1Qy1FMzhFLTRBOTgtOEY2RC0xNUMzOEY1MUNDQzY=</challenge>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      challenge = XMPP::Stanza::SASL2Challenge.new(node)

      challenge.body.strip.should eq "cj0xMkM0Q0Q1Qy1FMzhFLTRBOTgtOEY2RC0xNUMzOEY1MUNDQzY="
    end

    it "serializes challenge" do
      challenge = XMPP::Stanza::SASL2Challenge.new("dGVzdGNoYWxsZW5nZQ==")
      xml = challenge.to_xml

      xml.should contain("<challenge xmlns=\"urn:xmpp:sasl:2\">")
      xml.should contain("dGVzdGNoYWxsZW5nZQ==")
    end
  end

  describe XMPP::Stanza::SASL2Response do
    it "parses response" do
      xml = <<-XML
        <response xmlns='urn:xmpp:sasl:2'>Yz1iaXdzLHI9eEhNa2dLVVNXazlGSFF1Mzg=</response>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      response = XMPP::Stanza::SASL2Response.new(node)

      response.body.strip.should eq "Yz1iaXdzLHI9eEhNa2dLVVNXazlGSFF1Mzg="
    end

    it "serializes response" do
      response = XMPP::Stanza::SASL2Response.new("dGVzdHJlc3BvbnNl")
      xml = response.to_xml

      xml.should contain("<response xmlns=\"urn:xmpp:sasl:2\">")
      xml.should contain("dGVzdHJlc3BvbnNl")
    end
  end

  describe "SASL2 Protocol Flow" do
    it "demonstrates complete SASL2 authentication flow" do
      # Server advertises SASL2
      features_xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>SCRAM-SHA-256</mechanism>
            <mechanism>SCRAM-SHA-256-PLUS</mechanism>
            <inline>
              <sm xmlns='urn:xmpp:sm:3'/>
            </inline>
          </authentication>
        </stream:features>
      XML

      doc = XML.parse(features_xml)
      node = doc.first_element_child.not_nil!
      features = XMPP::Stanza::StreamFeatures.new(node)

      features.supports_sasl2?.should be_true
      sasl2 = features.sasl2_authentication
      sasl2.should_not be_nil

      if sasl2
        # Client sends authenticate
        ua = XMPP::Stanza::SASL2UserAgent.new(
          id: UUID.random.to_s,
          software: "TestClient"
        )

        auth = XMPP::Stanza::SASL2Authenticate.new(
          mechanism: "SCRAM-SHA-256",
          initial_response: "biwsbj10ZXN0LHI9bm9uY2U=",
          user_agent: ua
        )

        auth_xml = auth.to_xml
        auth_xml.should contain("mechanism=\"SCRAM-SHA-256\"")
        auth_xml.should contain("<user-agent")

        # Server sends challenge
        challenge = XMPP::Stanza::SASL2Challenge.new("cj1ub25jZQ==")
        challenge_xml = challenge.to_xml
        challenge_xml.should contain("<challenge xmlns=\"urn:xmpp:sasl:2\">")

        # Client sends response
        response = XMPP::Stanza::SASL2Response.new("Yz1iaXdz")
        response_xml = response.to_xml
        response_xml.should contain("<response xmlns=\"urn:xmpp:sasl:2\">")

        # Server sends success
        success = XMPP::Stanza::SASL2Success.new
        success.authorization_identifier = "user@example.org"
        success_xml = success.to_xml
        success_xml.should contain("<authorization-identifier>user@example.org</authorization-identifier>")
      end
    end

    it "demonstrates SASL2 with upgrade tasks" do
      # Server advertises SASL2 with upgrade support
      features_xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>SCRAM-SHA-1</mechanism>
            <mechanism>SCRAM-SHA-256</mechanism>
          </authentication>
          <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
            <mechanism>SCRAM-SHA-1</mechanism>
            <mechanism>SCRAM-SHA-256</mechanism>
            <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-256</upgrade>
          </mechanisms>
        </stream:features>
      XML

      doc = XML.parse(features_xml)
      node = doc.first_element_child.not_nil!
      features = XMPP::Stanza::StreamFeatures.new(node)

      features.supports_sasl2?.should be_true

      # Client requests upgrade
      auth = XMPP::Stanza::SASL2Authenticate.new(
        mechanism: "SCRAM-SHA-1",
        initial_response: "biwsbj10ZXN0",
        upgrades: ["UPGR-SCRAM-SHA-256"]
      )

      auth.upgrades.should contain("UPGR-SCRAM-SHA-256")

      # After successful auth, server sends continue
      continue = XMPP::Stanza::SASL2Continue.new
      continue.tasks = ["UPGR-SCRAM-SHA-256"]
      continue_xml = continue.to_xml
      continue_xml.should contain("<task>UPGR-SCRAM-SHA-256</task>")

      # Client initiates upgrade
      next_elem = XMPP::Stanza::SASL2Next.new(task: "UPGR-SCRAM-SHA-256")
      next_xml = next_elem.to_xml
      next_xml.should contain("task=\"UPGR-SCRAM-SHA-256\"")

      # Server sends salt
      task_data = XMPP::Stanza::SASL2TaskData.new(
        salt: "c2FsdA==",
        iterations: 4096
      )
      task_xml = task_data.to_xml
      task_xml.should contain("iterations=\"4096\"")

      # Client sends hash
      response_data = XMPP::Stanza::SASL2TaskData.new(hash: "aGFzaA==")
      response_xml = response_data.to_xml
      response_xml.should contain("<hash xmlns=\"urn:xmpp:scram-upgrade:0\">aGFzaA==</hash>")

      # Server sends final success
      success = XMPP::Stanza::SASL2Success.new
      success.authorization_identifier = "user@example.org"
      success_xml = success.to_xml
      success_xml.should contain("user@example.org")
    end
  end
end
