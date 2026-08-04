require "./spec_helper"
require "../src/xmpp/dns_srv"

describe XMPP::DnsSrv do
  describe ".resolve" do
    it "returns parsed SRV records from the resolver" do
      port = srv_dns_server(
        [{"_xmpps-client._tcp.example.org", 10_u16, 5_u16, 5223_u16, "tls.example.org"}],
        "_xmpps-client._tcp.example.org"
      )
      # Point the resolver at the fake server by monkey-patching nameservers.
      XMPP::DnsSrv.stub_nameservers ["127.0.0.1:#{port}"] do
        records = XMPP::DnsSrv.resolve "_xmpps-client", "example.org"
        records.size.should eq(1)
        records[0].priority.should eq(10)
        records[0].weight.should eq(5)
        records[0].port.should eq(5223)
        records[0].target.should eq("tls.example.org")
      end
    end

    it "returns empty when no records exist" do
      port = srv_dns_server([] of Tuple(String, UInt16, UInt16, UInt16, String), "_xmpps-client._tcp.example.org")
      XMPP::DnsSrv.stub_nameservers ["127.0.0.1:#{port}"] do
        XMPP::DnsSrv.resolve("_xmpps-client", "example.org").should be_empty
      end
    end

    it "returns empty when no resolver is configured" do
      XMPP::DnsSrv.stub_nameservers [] of String do
        XMPP::DnsSrv.resolve("_xmpps-client", "example.org").should be_empty
      end
    end
  end
end
