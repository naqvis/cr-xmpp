require "./spec_helper"

describe XMPP::SASLUpgrade do
  describe "task_name" do
    it "generates correct task name from mechanism" do
      XMPP::SASLUpgrade.task_name(XMPP::AuthMechanism::SCRAM_SHA_256).should eq "UPGR-SCRAM-SHA-256"
      XMPP::SASLUpgrade.task_name(XMPP::AuthMechanism::SCRAM_SHA_512).should eq "UPGR-SCRAM-SHA-512"
      XMPP::SASLUpgrade.task_name(XMPP::AuthMechanism::SCRAM_SHA_1).should eq "UPGR-SCRAM-SHA-1"
    end

    it "handles PLUS variants correctly" do
      XMPP::SASLUpgrade.task_name(XMPP::AuthMechanism::SCRAM_SHA_256_PLUS).should eq "UPGR-SCRAM-SHA-256"
      XMPP::SASLUpgrade.task_name(XMPP::AuthMechanism::SCRAM_SHA_512_PLUS).should eq "UPGR-SCRAM-SHA-512"
    end
  end

  describe "parse_task_name" do
    it "extracts mechanism from task name" do
      XMPP::SASLUpgrade.parse_task_name("UPGR-SCRAM-SHA-256").should eq "SCRAM-SHA-256"
      XMPP::SASLUpgrade.parse_task_name("UPGR-SCRAM-SHA-512").should eq "SCRAM-SHA-512"
      XMPP::SASLUpgrade.parse_task_name("UPGR-SCRAM-SHA-1").should eq "SCRAM-SHA-1"
    end

    it "returns nil for invalid task names" do
      XMPP::SASLUpgrade.parse_task_name("SCRAM-SHA-256").should be_nil
      XMPP::SASLUpgrade.parse_task_name("INVALID").should be_nil
    end
  end

  describe "scram_upgrade?" do
    it "identifies SCRAM upgrade tasks" do
      XMPP::SASLUpgrade.scram_upgrade?("UPGR-SCRAM-SHA-256").should be_true
      XMPP::SASLUpgrade.scram_upgrade?("UPGR-SCRAM-SHA-512").should be_true
      XMPP::SASLUpgrade.scram_upgrade?("UPGR-SCRAM-SHA-1").should be_true
    end

    it "rejects non-SCRAM tasks" do
      XMPP::SASLUpgrade.scram_upgrade?("UPGR-OTHER").should be_false
      XMPP::SASLUpgrade.scram_upgrade?("SCRAM-SHA-256").should be_false
    end
  end

  describe "algorithm_from_mechanism" do
    it "returns correct algorithm for SHA-512" do
      algo = XMPP::SASLUpgrade.algorithm_from_mechanism("SCRAM-SHA-512")
      algo.should eq OpenSSL::Algorithm::SHA512
    end

    it "returns correct algorithm for SHA-256" do
      algo = XMPP::SASLUpgrade.algorithm_from_mechanism("SCRAM-SHA-256")
      algo.should eq OpenSSL::Algorithm::SHA256
    end

    it "returns correct algorithm for SHA-1" do
      algo = XMPP::SASLUpgrade.algorithm_from_mechanism("SCRAM-SHA-1")
      algo.should eq OpenSSL::Algorithm::SHA1
    end
  end

  describe "compute_scram_hash" do
    it "computes correct SCRAM hash for SHA-256" do
      password = "password"
      salt = Base64.decode("QV9TWENSWFE2c2VrOGJmX1o=")
      iterations = 4096
      algorithm = OpenSSL::Algorithm::SHA256

      hash = XMPP::SASLUpgrade.compute_scram_hash(password, salt, iterations, algorithm)
      hash.should_not be_empty
      hash.should be_a(String)
    end

    it "produces different hashes for different passwords" do
      salt = Base64.decode("QV9TWENSWFE2c2VrOGJmX1o=")
      iterations = 4096
      algorithm = OpenSSL::Algorithm::SHA256

      hash1 = XMPP::SASLUpgrade.compute_scram_hash("password1", salt, iterations, algorithm)
      hash2 = XMPP::SASLUpgrade.compute_scram_hash("password2", salt, iterations, algorithm)

      hash1.should_not eq hash2
    end

    it "produces different hashes for different salts" do
      password = "password"
      iterations = 4096
      algorithm = OpenSSL::Algorithm::SHA256

      salt1 = Base64.decode("QV9TWENSWFE2c2VrOGJmX1o=")
      salt2 = Base64.decode("YW5vdGhlcnNhbHQ=")

      hash1 = XMPP::SASLUpgrade.compute_scram_hash(password, salt1, iterations, algorithm)
      hash2 = XMPP::SASLUpgrade.compute_scram_hash(password, salt2, iterations, algorithm)

      hash1.should_not eq hash2
    end
  end

  describe "select_upgrades" do
    it "selects stronger SCRAM variants" do
      current = XMPP::AuthMechanism::SCRAM_SHA_1
      available_mechs = ["SCRAM-SHA-1", "SCRAM-SHA-256", "SCRAM-SHA-512"]
      available_upgrades = ["UPGR-SCRAM-SHA-256", "UPGR-SCRAM-SHA-512"]

      upgrades = XMPP::SASLUpgrade.select_upgrades(current, available_mechs, available_upgrades)
      upgrades.should contain("UPGR-SCRAM-SHA-512")
      upgrades.should contain("UPGR-SCRAM-SHA-256")
    end

    it "does not upgrade to weaker variants" do
      current = XMPP::AuthMechanism::SCRAM_SHA_512
      available_mechs = ["SCRAM-SHA-1", "SCRAM-SHA-256", "SCRAM-SHA-512"]
      available_upgrades = ["UPGR-SCRAM-SHA-1", "UPGR-SCRAM-SHA-256"]

      upgrades = XMPP::SASLUpgrade.select_upgrades(current, available_mechs, available_upgrades)
      upgrades.should be_empty
    end

    it "only selects upgrades server supports" do
      current = XMPP::AuthMechanism::SCRAM_SHA_1
      available_mechs = ["SCRAM-SHA-1", "SCRAM-SHA-256"]
      available_upgrades = ["UPGR-SCRAM-SHA-256", "UPGR-SCRAM-SHA-512"]

      upgrades = XMPP::SASLUpgrade.select_upgrades(current, available_mechs, available_upgrades)
      upgrades.should contain("UPGR-SCRAM-SHA-256")
      upgrades.should_not contain("UPGR-SCRAM-SHA-512")
    end

    it "handles PLUS variants in available mechanisms" do
      current = XMPP::AuthMechanism::SCRAM_SHA_1_PLUS
      available_mechs = ["SCRAM-SHA-1-PLUS", "SCRAM-SHA-256-PLUS"]
      available_upgrades = ["UPGR-SCRAM-SHA-256"]

      upgrades = XMPP::SASLUpgrade.select_upgrades(current, available_mechs, available_upgrades)
      upgrades.should contain("UPGR-SCRAM-SHA-256")
    end
  end
end

describe "SASL Mechanisms with Upgrade Tasks" do
  describe "upgrade tasks parsing via StreamFeatures" do
    it "parses upgrade tasks from stream features XML" do
      xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
            <mechanism>SCRAM-SHA-1</mechanism>
            <mechanism>SCRAM-SHA-256</mechanism>
            <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-256</upgrade>
            <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-512</upgrade>
          </mechanisms>
        </stream:features>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      features = XMPP::Stanza::StreamFeatures.new(node)

      mechs = features.mechanisms
      mechs.should_not be_nil
      if mechs
        mechs.upgrade_tasks.should contain("UPGR-SCRAM-SHA-256")
        mechs.upgrade_tasks.should contain("UPGR-SCRAM-SHA-512")
      end
    end

    it "checks for specific upgrade support" do
      xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
            <mechanism>SCRAM-SHA-256</mechanism>
            <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-256</upgrade>
          </mechanisms>
        </stream:features>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      features = XMPP::Stanza::StreamFeatures.new(node)

      mechs = features.mechanisms
      mechs.should_not be_nil
      if mechs
        mechs.supports_upgrade?("UPGR-SCRAM-SHA-256").should be_true
        mechs.supports_upgrade?("UPGR-SCRAM-SHA-512").should be_false
      end
    end

    it "filters SCRAM upgrade tasks" do
      xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
            <mechanism>SCRAM-SHA-256</mechanism>
            <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-256</upgrade>
            <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-512</upgrade>
            <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-OTHER</upgrade>
          </mechanisms>
        </stream:features>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      features = XMPP::Stanza::StreamFeatures.new(node)

      mechs = features.mechanisms
      mechs.should_not be_nil
      if mechs
        scram_upgrades = mechs.available_scram_upgrades
        scram_upgrades.size.should eq 2
        scram_upgrades.should contain("UPGR-SCRAM-SHA-256")
        scram_upgrades.should contain("UPGR-SCRAM-SHA-512")
        scram_upgrades.should_not contain("UPGR-OTHER")
      end
    end
  end
end

describe XMPP::Stanza::SASL2Authenticate do
  describe "parsing" do
    it "parses authenticate with upgrades" do
      xml = <<-XML
        <authenticate xmlns='urn:xmpp:sasl:2' mechanism='SCRAM-SHA-1-PLUS'>
          <initial-response>cD10bHMtZXhwb3J0ZXI=</initial-response>
          <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-256</upgrade>
          <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-512</upgrade>
        </authenticate>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      auth = XMPP::Stanza::SASL2Authenticate.new(node)

      auth.mechanism.should eq "SCRAM-SHA-1-PLUS"
      auth.initial_response.should eq "cD10bHMtZXhwb3J0ZXI="
      auth.upgrades.size.should eq 2
      auth.upgrades.should contain("UPGR-SCRAM-SHA-256")
      auth.upgrades.should contain("UPGR-SCRAM-SHA-512")
    end
  end

  describe "to_xml" do
    it "serializes authenticate with upgrades" do
      auth = XMPP::Stanza::SASL2Authenticate.new(
        mechanism: "SCRAM-SHA-256",
        initial_response: "test",
        upgrades: ["UPGR-SCRAM-SHA-512"]
      )

      xml = auth.to_xml

      xml.should contain("mechanism=\"SCRAM-SHA-256\"")
      xml.should contain("<initial-response>test</initial-response>")
      xml.should contain("<upgrade xmlns=\"urn:xmpp:sasl:upgrade:0\">UPGR-SCRAM-SHA-512</upgrade>")
    end
  end
end

describe XMPP::Stanza::SASL2Continue do
  describe "parsing" do
    it "parses continue with tasks" do
      xml = <<-XML
        <continue xmlns='urn:xmpp:sasl:2'>
          <additional-data>SSdtIGJvcmVkIG5vdy4=</additional-data>
          <tasks>
            <task>UPGR-SCRAM-SHA-256</task>
          </tasks>
          <text>Upgrade required</text>
        </continue>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      cont = XMPP::Stanza::SASL2Continue.new(node)

      cont.additional_data.should eq "SSdtIGJvcmVkIG5vdy4="
      cont.tasks.should contain("UPGR-SCRAM-SHA-256")
      cont.text.should eq "Upgrade required"
    end
  end

  describe "to_xml" do
    it "serializes continue with tasks" do
      cont = XMPP::Stanza::SASL2Continue.new
      cont.tasks = ["UPGR-SCRAM-SHA-256"]
      cont.text = "Please upgrade"

      xml = cont.to_xml

      xml.should contain("<task>UPGR-SCRAM-SHA-256</task>")
      xml.should contain("<text>Please upgrade</text>")
    end
  end
end

describe XMPP::Stanza::SASL2TaskData do
  describe "parsing salt" do
    it "parses salt with iterations" do
      xml = <<-XML
        <task-data xmlns='urn:xmpp:sasl:2'>
          <salt xmlns='urn:xmpp:scram-upgrade:0' iterations='4096'>QV9TWENSWFE2c2VrOGJmX1o=</salt>
        </task-data>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      data = XMPP::Stanza::SASL2TaskData.new(node)

      data.salt.should eq "QV9TWENSWFE2c2VrOGJmX1o="
      data.iterations.should eq 4096
    end
  end

  describe "parsing hash" do
    it "parses hash response" do
      xml = <<-XML
        <task-data xmlns='urn:xmpp:sasl:2'>
          <hash xmlns='urn:xmpp:scram-upgrade:0'>BzOnw3Pc5H4bOLlPZ/8JAy6wnTpH05aH21KW2+Xfpaw=</hash>
        </task-data>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      data = XMPP::Stanza::SASL2TaskData.new(node)

      data.hash.should eq "BzOnw3Pc5H4bOLlPZ/8JAy6wnTpH05aH21KW2+Xfpaw="
    end
  end

  describe "to_xml" do
    it "serializes salt with iterations" do
      data = XMPP::Stanza::SASL2TaskData.new(salt: "test_salt", iterations: 4096)

      xml = data.to_xml

      xml.should contain("iterations=\"4096\"")
      xml.should contain("test_salt")
    end

    it "serializes hash" do
      data = XMPP::Stanza::SASL2TaskData.new(hash: "test_hash")

      xml = data.to_xml

      xml.should contain("<hash xmlns=\"urn:xmpp:scram-upgrade:0\">test_hash</hash>")
    end
  end
end

describe XMPP::Stanza::SASL2Next do
  describe "parsing" do
    it "parses next with task attribute" do
      xml = <<-XML
        <next xmlns='urn:xmpp:sasl:2' task='UPGR-SCRAM-SHA-256'/>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      next_elem = XMPP::Stanza::SASL2Next.new(node)

      next_elem.task.should eq "UPGR-SCRAM-SHA-256"
    end
  end

  describe "to_xml" do
    it "serializes next with task" do
      next_elem = XMPP::Stanza::SASL2Next.new(task: "UPGR-SCRAM-SHA-512")

      xml = next_elem.to_xml

      xml.should contain("task=\"UPGR-SCRAM-SHA-512\"")
    end
  end
end

describe XMPP::Stanza::SASL2Success do
  describe "parsing" do
    it "parses success with authorization identifier" do
      xml = <<-XML
        <success xmlns='urn:xmpp:sasl:2'>
          <authorization-identifier>user@example.org</authorization-identifier>
        </success>
      XML

      doc = XML.parse(xml)
      node = doc.first_element_child.not_nil!
      success = XMPP::Stanza::SASL2Success.new(node)

      success.authorization_identifier.should eq "user@example.org"
    end
  end

  describe "to_xml" do
    it "serializes success with authorization identifier" do
      success = XMPP::Stanza::SASL2Success.new
      success.authorization_identifier = "user@example.org"

      xml = success.to_xml

      xml.should contain("<authorization-identifier>user@example.org</authorization-identifier>")
    end
  end
end

describe "XEP-0480 Full Protocol Flow" do
  it "demonstrates complete upgrade flow with stream features" do
    # Server advertises upgrade tasks in stream features
    features_xml = <<-XML
      <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
        <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
          <mechanism>SCRAM-SHA-1-PLUS</mechanism>
          <mechanism>SCRAM-SHA-256-PLUS</mechanism>
          <mechanism>SCRAM-SHA-512-PLUS</mechanism>
          <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-256</upgrade>
          <upgrade xmlns='urn:xmpp:sasl:upgrade:0'>UPGR-SCRAM-SHA-512</upgrade>
          <channel-binding type='tls-server-end-point'/>
        </mechanisms>
      </stream:features>
    XML

    doc = XML.parse(features_xml)
    node = doc.first_element_child.not_nil!
    features = XMPP::Stanza::StreamFeatures.new(node)

    # Verify server advertises upgrades
    mechs = features.mechanisms
    mechs.should_not be_nil
    if mechs
      mechs.upgrade_tasks.size.should eq 2
      mechs.supports_upgrade?("UPGR-SCRAM-SHA-256").should be_true
      mechs.supports_upgrade?("UPGR-SCRAM-SHA-512").should be_true

      # Client would select upgrades (authenticating with SHA-1, upgrading to SHA-256 and SHA-512)
      current = XMPP::AuthMechanism::SCRAM_SHA_1_PLUS
      upgrades = XMPP::SASLUpgrade.select_upgrades(
        current,
        mechs.mechanism,
        mechs.upgrade_tasks
      )

      upgrades.should contain("UPGR-SCRAM-SHA-512")
      upgrades.should contain("UPGR-SCRAM-SHA-256")
    end
  end

  it "demonstrates upgrade task data exchange" do
    # Server sends salt and iterations
    task_data_xml = <<-XML
      <task-data xmlns='urn:xmpp:sasl:2'>
        <salt xmlns='urn:xmpp:scram-upgrade:0' iterations='4096'>QV9TWENSWFE2c2VrOGJmX1o=</salt>
      </task-data>
    XML

    doc = XML.parse(task_data_xml)
    node = doc.first_element_child.not_nil!
    task_data = XMPP::Stanza::SASL2TaskData.new(node)

    task_data.salt.should eq "QV9TWENSWFE2c2VrOGJmX1o="
    task_data.iterations.should eq 4096

    # Client computes hash
    password = "test_password"
    salt = Base64.decode(task_data.salt)
    algorithm = OpenSSL::Algorithm::SHA256

    hash = XMPP::SASLUpgrade.compute_scram_hash(password, salt, task_data.iterations, algorithm)
    hash.should_not be_empty

    # Client sends hash back
    response = XMPP::Stanza::SASL2TaskData.new(hash: hash)
    xml = response.to_xml

    xml.should contain("<hash xmlns=\"urn:xmpp:scram-upgrade:0\">")
    xml.should contain(hash)
  end
end
