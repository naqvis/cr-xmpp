require "./spec_helper"
require "http/server"
require "http/server/handlers/websocket_handler"

private def auto_config(port : Int32) : XMPP::Config
  XMPP::Config.new(
    jid: "test@example.org/auto",
    password: "secret",
    host: "127.0.0.1",
    port: port,
    transport: XMPP::TransportMode::Auto,
    tls: true
  )
end

describe XMPP::AutoTransport do
  it "returns the TCP transport when the TCP path succeeds" do
    server = TCPServer.new("127.0.0.1", 0)
    port = server.local_address.as(Socket::IPAddress).port
    spawn do
      client = server.accept
      client.write("hello".to_slice)
    end

    config = auto_config(port)
    transport = XMPP::AutoTransport.open(config) do |_domain, _config|
      fail "discovery must not run when TCP connects"
    end
    transport.should be_a(XMPP::TcpTransport)
    buffer = Bytes.new(8)
    count = transport.read(buffer)
    String.new(buffer[0, count]).should eq "hello"
  ensure
    transport.try(&.close)
    server.try(&.close)
  end

  it "falls back to a discovered WebSocket endpoint when TCP fails" do
    handler = HTTP::WebSocketHandler.new(["xmpp"]) do |ws, _ctx|
      ws.on_message { |msg| ws.send msg }
    end
    ws_server = HTTP::Server.new(handler)
    ws_address = ws_server.bind_tcp "127.0.0.1", 0
    spawn { ws_server.listen }

    config = auto_config(1) # connection refused on port 1
    discover = ->(domain : String, config : XMPP::Config) do
      [XMPP::AlternativeEndpoint.new(
        XMPP::EndpointKind::WebSocket,
        URI.parse("ws://127.0.0.1:#{ws_address.port}/ws")
      )]
    end

    transport = XMPP::AutoTransport.open(config, discover)
    transport.should be_a(XMPP::WebSocketTransport)
    transport.encrypted?.should be_false
  ensure
    transport.try(&.close)
    ws_server.try(&.close)
  end

  it "raises ConnectionError when nothing is discoverable" do
    config = auto_config(1)
    discover = ->(domain : String, config : XMPP::Config) { [] of XMPP::AlternativeEndpoint }
    expect_raises(XMPP::ConnectionError, /no alternative connection endpoints/) do
      XMPP::AutoTransport.open(config, discover)
    end
  end
end
