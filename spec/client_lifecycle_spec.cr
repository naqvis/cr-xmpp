require "./spec_helper"

describe XMPP::Client do
  it "exposes its lifecycle and raises a typed error when sending while disconnected" do
    config = XMPP::Config.new(
      jid: "test@example.com/spec",
      password: "secret",
      host: "example.com",
      auto_presence: false
    )
    client = XMPP::Client.new(config, XMPP::Router.new)

    client.current_state.should eq XMPP::ConnectionState::Disconnected
    expect_raises(XMPP::NotConnectedError, "client is not connected") do
      client.send("<presence/>")
    end
  end
end

describe XMPP::Component do
  it "uses the same typed disconnected-send contract" do
    options = XMPP::ComponentOptions.new(
      domain: "component.example.com",
      secret: "secret",
      host: "example.com",
      port: 5347,
      name: "spec component",
      category: "component",
      type: "generic"
    )
    component = XMPP::Component.new(options, XMPP::Router.new)

    component.current_state.should eq XMPP::ConnectionState::Disconnected
    expect_raises(XMPP::NotConnectedError, "component is not connected") do
      component.send("<presence/>")
    end
  end
end
