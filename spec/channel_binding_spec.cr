require "./spec_helper"

describe XMPP::ChannelBinding do
  describe "Type" do
    it "converts to string correctly" do
      XMPP::ChannelBinding::Type::TLS_UNIQUE.to_s.should eq "tls-unique"
      XMPP::ChannelBinding::Type::TLS_SERVER_END_POINT.to_s.should eq "tls-server-end-point"
      XMPP::ChannelBinding::Type::TLS_EXPORTER.to_s.should eq "tls-exporter"
    end

    it "parses from string correctly" do
      XMPP::ChannelBinding::Type.from_string("tls-unique").should eq XMPP::ChannelBinding::Type::TLS_UNIQUE
      XMPP::ChannelBinding::Type.from_string("tls-server-end-point").should eq XMPP::ChannelBinding::Type::TLS_SERVER_END_POINT
      XMPP::ChannelBinding::Type.from_string("tls-exporter").should eq XMPP::ChannelBinding::Type::TLS_EXPORTER
      XMPP::ChannelBinding::Type.from_string("unknown").should be_nil
    end
  end

  describe "supports_channel_binding?" do
    it "detects SCRAM-PLUS mechanisms" do
      XMPP::ChannelBinding.supports_channel_binding?("SCRAM-SHA-256-PLUS").should be_true
      XMPP::ChannelBinding.supports_channel_binding?("SCRAM-SHA-512-PLUS").should be_true
      XMPP::ChannelBinding.supports_channel_binding?("SCRAM-SHA-1-PLUS").should be_true
    end

    it "rejects non-PLUS mechanisms" do
      XMPP::ChannelBinding.supports_channel_binding?("SCRAM-SHA-256").should be_false
      XMPP::ChannelBinding.supports_channel_binding?("PLAIN").should be_false
      XMPP::ChannelBinding.supports_channel_binding?("DIGEST-MD5").should be_false
    end
  end

  describe "base_mechanism" do
    it "removes -PLUS suffix" do
      XMPP::ChannelBinding.base_mechanism("SCRAM-SHA-256-PLUS").should eq "SCRAM-SHA-256"
      XMPP::ChannelBinding.base_mechanism("SCRAM-SHA-512-PLUS").should eq "SCRAM-SHA-512"
    end

    it "returns unchanged for non-PLUS mechanisms" do
      XMPP::ChannelBinding.base_mechanism("SCRAM-SHA-256").should eq "SCRAM-SHA-256"
      XMPP::ChannelBinding.base_mechanism("PLAIN").should eq "PLAIN"
    end
  end
end

describe XMPP::AuthMechanism do
  describe "uses_channel_binding?" do
    it "returns true for PLUS variants" do
      XMPP::AuthMechanism::SCRAM_SHA_512_PLUS.uses_channel_binding?.should be_true
      XMPP::AuthMechanism::SCRAM_SHA_256_PLUS.uses_channel_binding?.should be_true
      XMPP::AuthMechanism::SCRAM_SHA_1_PLUS.uses_channel_binding?.should be_true
    end

    it "returns false for non-PLUS variants" do
      XMPP::AuthMechanism::SCRAM_SHA_512.uses_channel_binding?.should be_false
      XMPP::AuthMechanism::SCRAM_SHA_256.uses_channel_binding?.should be_false
      XMPP::AuthMechanism::SCRAM_SHA_1.uses_channel_binding?.should be_false
      XMPP::AuthMechanism::PLAIN.uses_channel_binding?.should be_false
    end
  end

  describe "base_mechanism" do
    it "removes -PLUS suffix" do
      XMPP::AuthMechanism::SCRAM_SHA_256_PLUS.base_mechanism.should eq "SCRAM-SHA-256"
      XMPP::AuthMechanism::SCRAM_SHA_512_PLUS.base_mechanism.should eq "SCRAM-SHA-512"
    end

    it "returns unchanged for non-PLUS mechanisms" do
      XMPP::AuthMechanism::SCRAM_SHA_256.base_mechanism.should eq "SCRAM-SHA-256"
      XMPP::AuthMechanism::PLAIN.base_mechanism.should eq "PLAIN"
    end
  end

  describe "to_s" do
    it "formats PLUS variants correctly" do
      XMPP::AuthMechanism::SCRAM_SHA_512_PLUS.to_s.should eq "SCRAM-SHA-512-PLUS"
      XMPP::AuthMechanism::SCRAM_SHA_256_PLUS.to_s.should eq "SCRAM-SHA-256-PLUS"
      XMPP::AuthMechanism::SCRAM_SHA_1_PLUS.to_s.should eq "SCRAM-SHA-1-PLUS"
    end
  end
end

describe XMPP::ScramDowngradeProtection do
  describe "check_downgrade" do
    it "detects potential downgrade when PLUS variant is available" do
      available = ["SCRAM-SHA-256", "SCRAM-SHA-256-PLUS"]
      selected = XMPP::AuthMechanism::SCRAM_SHA_256

      XMPP::ScramDowngradeProtection.check_downgrade(
        selected, available, true
      ).should be_true
    end

    it "does not flag when PLUS variant is not available" do
      available = ["SCRAM-SHA-256"]
      selected = XMPP::AuthMechanism::SCRAM_SHA_256

      XMPP::ScramDowngradeProtection.check_downgrade(
        selected, available, true
      ).should be_false
    end

    it "does not flag when using PLUS variant" do
      available = ["SCRAM-SHA-256", "SCRAM-SHA-256-PLUS"]
      selected = XMPP::AuthMechanism::SCRAM_SHA_256_PLUS

      XMPP::ScramDowngradeProtection.check_downgrade(
        selected, available, true
      ).should be_false
    end

    it "does not flag when TLS is not available" do
      available = ["SCRAM-SHA-256", "SCRAM-SHA-256-PLUS"]
      selected = XMPP::AuthMechanism::SCRAM_SHA_256

      XMPP::ScramDowngradeProtection.check_downgrade(
        selected, available, false
      ).should be_false
    end
  end
end
