require "./spec_helper"
require "../src/xmpp/connection"

private def connection_config(host : String? = nil, prefer_direct_tls : Bool = false, port : Int32 = 5222) : XMPP::Config
  XMPP::Config.new(
    jid: "test@example.org/resource",
    password: "secret",
    host: host || "",
    port: port,
    prefer_direct_tls: prefer_direct_tls,
  )
end

describe XMPP::ConnectionResolver do
  describe ".resolve" do
    it "returns the configured host/port in STARTTLS mode when a host is explicit" do
      config = connection_config(host: "chat.example.org")
      endpoints = XMPP::ConnectionResolver.resolve(config)
      endpoints.size.should eq(1)
      endpoints[0].host.should eq("chat.example.org")
      endpoints[0].port.should eq(5222)
      endpoints[0].mode.start_tls?.should be_true
    end

    it "returns the configured host/port when direct TLS is not requested" do
      config = connection_config
      endpoints = XMPP::ConnectionResolver.resolve(config)
      endpoints.size.should eq(1)
      endpoints[0].host.should eq("example.org")
      endpoints[0].mode.start_tls?.should be_true
    end

    it "prefers direct TLS SRV records when enabled" do
      port = srv_dns_server(
        [
          {"_xmpps-client._tcp.example.org", 10_u16, 5_u16, 5223_u16, "tls.example.org"},
          {"_xmpp-client._tcp.example.org", 10_u16, 5_u16, 5222_u16, "starttls.example.org"},
        ],
        "_xmpp-client._tcp.example.org"
      )
      XMPP::DnsSrv.stub_nameservers ["127.0.0.1:#{port}"] do
        endpoints = XMPP::ConnectionResolver.resolve(connection_config(prefer_direct_tls: true))
        endpoints.size.should eq(2)
        endpoints[0].host.should eq("tls.example.org")
        endpoints[0].port.should eq(5223)
        endpoints[0].mode.direct_tls?.should be_true
        endpoints[1].host.should eq("starttls.example.org")
        endpoints[1].mode.start_tls?.should be_true
      end
    end

    it "falls back to the configured host when no SRV records exist" do
      port = srv_dns_server([] of Tuple(String, UInt16, UInt16, UInt16, String), "_xmpps-client._tcp.example.org")
      XMPP::DnsSrv.stub_nameservers ["127.0.0.1:#{port}"] do
        endpoints = XMPP::ConnectionResolver.resolve(connection_config(prefer_direct_tls: true))
        endpoints.size.should eq(1)
        endpoints[0].host.should eq("example.org")
        endpoints[0].mode.start_tls?.should be_true
      end
    end
  end
end
