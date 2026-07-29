require "./spec_helper"

describe "XEP-0515: TLS Channel-Binding Downgrade Protection" do
  describe ".version_code" do
    it "encodes the TLS wire version as four lower-case hexadecimal characters" do
      protection = XMPP::TLSChannelBindingDowngradeProtection

      protection.version_code("TLSv1.3").should eq "0304"
      protection.version_code("TLSv1.2").should eq "0303"
      protection.version_code("TLSv1.1").should eq "0302"
      protection.version_code("TLSv1").should eq "0301"
      protection.version_code("TLSv1.0").should eq "0301"
    end

    it "does not guess the code for an unknown TLS version" do
      XMPP::TLSChannelBindingDowngradeProtection.version_code("TLSv2").should be_nil
    end
  end

  describe ".verify!" do
    it "accepts matching server and local TLS versions" do
      XMPP::TLSChannelBindingDowngradeProtection.verify!("0304", "TLSv1.3")
    end

    it "allows a server that does not send the optional attribute" do
      XMPP::TLSChannelBindingDowngradeProtection.verify!(nil, "TLSv1.3")
    end

    it "rejects a TLS version downgrade" do
      expect_raises(XMPP::AuthenticationError, /TLS version mismatch/) do
        XMPP::TLSChannelBindingDowngradeProtection.verify!("0303", "TLSv1.3")
      end
    end

    it "rejects the attribute when the connection is not protected by TLS" do
      expect_raises(XMPP::AuthenticationError, /no TLS connection/) do
        XMPP::TLSChannelBindingDowngradeProtection.verify!("0304", nil)
      end
    end

    it "fails closed for a negotiated TLS version it cannot encode" do
      expect_raises(XMPP::AuthenticationError, /unsupported negotiated TLS version/) do
        XMPP::TLSChannelBindingDowngradeProtection.verify!("0305", "TLSv2")
      end
    end
  end
end
