require "./spec_helper"

private WEBSOCKET_REL = "urn:xmpp:alt-connections:websocket"
private BOSH_REL      = "urn:xmpp:alt-connections:xbosh"

private def discovery_config : XMPP::Config
  XMPP::Config.new(jid: "test@example.org", password: "secret", host: "example.org")
end

private def stub_fetcher(bodies : Hash(String, String))
  ->(url : String) { bodies[url]? }
end

describe XMPP::AltConnectionResolver do
  it "parses XRD host-meta links and orders WebSocket before BOSH, secure first" do
    xrd = <<-XML
      <?xml version='1.0'?>
      <XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>
        <Link rel='#{BOSH_REL}' href='http://example.org:5280/http-bind'/>
        <Link rel='#{WEBSOCKET_REL}' href='wss://example.org/ws'/>
        <Link rel='#{WEBSOCKET_REL}' href='ws://example.org/ws'/>
        <Link rel='urn:something:else' href='wss://example.org/other'/>
        <Link rel='#{BOSH_REL}' href='ftp://example.org/x'/>
      </XRD>
      XML
    fetcher = stub_fetcher({
      "https://example.org/.well-known/host-meta" => xrd,
    })

    endpoints = XMPP::AltConnectionResolver.discover("example.org", discovery_config, fetcher: fetcher)

    endpoints.map(&.kind).should eq [
      XMPP::EndpointKind::WebSocket,
      XMPP::EndpointKind::WebSocket,
      XMPP::EndpointKind::Bosh,
    ]
    endpoints.map(&.url.to_s).should eq [
      "wss://example.org/ws",
      "ws://example.org/ws",
      "http://example.org:5280/http-bind",
    ]
  end

  it "falls back to JRD host-meta when XRD yields nothing" do
    xrd = "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'/>"
    jrd = <<-JSON
      {
        "subject": "https://example.org",
        "links": [
          {"rel": "urn:xmpp:alt-connections:websocket", "href": "wss://example.org/ws"},
          {"rel": "urn:xmpp:alt-connections:xbosh", "href": "https://example.org:5280/http-bind"}
        ]
      }
      JSON
    fetcher = stub_fetcher({
      "https://example.org/.well-known/host-meta"      => xrd,
      "https://example.org/.well-known/host-meta.json" => jrd,
    })

    endpoints = XMPP::AltConnectionResolver.discover("example.org", discovery_config, fetcher: fetcher)

    endpoints.map(&.kind).should eq [
      XMPP::EndpointKind::WebSocket,
      XMPP::EndpointKind::Bosh,
    ]
    endpoints[1].url.to_s.should eq "https://example.org:5280/http-bind"
  end

  it "returns an empty list when neither host-meta form has alt-connection links" do
    fetcher = stub_fetcher({
      "https://example.org/.well-known/host-meta"      => "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'/>",
      "https://example.org/.well-known/host-meta.json" => "{}",
    })

    XMPP::AltConnectionResolver.discover("example.org", discovery_config, fetcher: fetcher).should be_empty
  end

  it "tolerates an unreachable host-meta endpoint" do
    fetcher = stub_fetcher({} of String => String)
    XMPP::AltConnectionResolver.discover("example.org", discovery_config, fetcher: fetcher).should be_empty
  end
end
