require "./spec_helper"

describe XMPP::TLSConnection do
  it "builds a client context that honors skip_cert_verify" do
    config = XMPP::Config.new(
      jid: "test@example.org",
      password: "secret",
      host: "example.org",
      skip_cert_verify: true
    )
    context = XMPP::TLSConnection.client_context(config)
    context.verify_mode.should eq OpenSSL::SSL::VerifyMode::None
  end

  it "keeps peer verification enabled by default" do
    config = XMPP::Config.new(jid: "test@example.org", password: "secret", host: "example.org")
    context = XMPP::TLSConnection.client_context(config)
    context.verify_mode.should_not eq OpenSSL::SSL::VerifyMode::None
  end
end
