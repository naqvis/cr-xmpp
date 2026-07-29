require "./spec_helper"

describe XMPP::Config do
  it "uses secure transport defaults" do
    config = XMPP::Config.new(
      jid: "romeo@example.org",
      password: "secret",
      host: "example.org"
    )

    config.tls?.should be_true
    config.skip_cert_verify?.should be_false
    config.io_timeout.should eq 30
    config.max_stanza_size.should eq XMPP::XMLStreamReader::DEFAULT_MAX_ELEMENT_SIZE
    config.tls_ca_certificates.should be_nil
    config.sasl_auth_order.should eq XMPP::SASL_AUTH_ORDER
    config.sasl_auth_order.should_not contain(XMPP::AuthMechanism::PLAIN)
    config.sasl_auth_order.should_not contain(XMPP::AuthMechanism::DIGEST_MD5)
  end

  it "accepts a custom TLS trust bundle" do
    config = XMPP::Config.new(
      jid: "romeo@example.org",
      password: "secret",
      host: "example.org",
      tls_ca_certificates: "/etc/example/ca.pem"
    )

    config.tls_ca_certificates.should eq "/etc/example/ca.pem"
  end

  it "supports explicit legacy SASL compatibility" do
    config = XMPP::Config.new(
      jid: "romeo@example.org",
      password: "secret",
      host: "example.org",
      sasl_auth_order: XMPP::LEGACY_SASL_AUTH_ORDER
    )

    config.sasl_auth_order.should eq XMPP::LEGACY_SASL_AUTH_ORDER
    config.sasl_auth_order.should contain(XMPP::AuthMechanism::PLAIN)
    config.sasl_auth_order.should contain(XMPP::AuthMechanism::DIGEST_MD5)
    config.sasl_auth_order.should contain(XMPP::AuthMechanism::ANONYMOUS)
  end

  it "rejects invalid resource limits" do
    expect_raises(XMPP::ConfigurationError, /time_out/) do
      XMPP::Config.new("romeo@example.org", "secret", "example.org", time_out: 0)
    end

    expect_raises(ArgumentError, /io_timeout/) do
      XMPP::Config.new("romeo@example.org", "secret", "example.org", io_timeout: 0)
    end

    expect_raises(ArgumentError, /max_stanza_size/) do
      XMPP::Config.new("romeo@example.org", "secret", "example.org", max_stanza_size: 0)
    end
  end

  it "uses a typed configuration error for missing credentials" do
    expect_raises(XMPP::ConfigurationError, /missing password/) do
      XMPP::Config.new("romeo@example.org", "", "example.org")
    end
  end
end
