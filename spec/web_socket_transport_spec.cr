require "./spec_helper"
require "http/server"
require "http/server/handlers/websocket_handler"

private FRAMING_NS = "urn:ietf:params:xml:ns:xmpp-framing"

private def eventually(timeout = 3.seconds, interval = 5.milliseconds, &block)
  deadline = Time.instant + timeout
  loop do
    begin
      block.call
      return
    rescue ex
      raise ex if Time.instant >= deadline
      sleep interval
    end
  end
end

private def ws_config(url : String) : XMPP::Config
  XMPP::Config.new(
    jid: "test@example.org/ws",
    password: "secret",
    host: "example.org",
    transport: XMPP::TransportMode::WebSocket,
    url: url,
    tls: true
  )
end

private class WsFixture
  getter pinged = Channel(Nil).new
  getter server : HTTP::Server
  getter port : Int32

  @received = [] of String
  @received_mutex = Mutex.new

  def initialize(subprotocols : Array(String)? = ["xmpp"])
    handler = HTTP::WebSocketHandler.new(subprotocols) do |ws, _ctx|
      ws.on_ping { @pinged.send(nil) }
      ws.on_message do |msg|
        @received_mutex.synchronize { @received << msg }
        case msg
        when /\A<open\b/
          ws.send "<open xmlns='#{FRAMING_NS}' from='example.org' id='stream-1'/>"
        when /\A<close\b/
          ws.send "<close xmlns='#{FRAMING_NS}'/>"
        else
          ws.send msg
        end
      end
    end
    @server = HTTP::Server.new(handler)
    address = @server.bind_tcp "127.0.0.1", 0
    @port = address.port
    spawn { @server.listen }
  end

  def received_messages : Array(String)
    @received_mutex.synchronize { @received.dup }
  end

  def close
    @server.close
  end
end

describe XMPP::WebSocketTransport do
  it "maps a stream header write to <open/> and synthesizes the inbound stream header" do
    fixture = WsFixture.new
    transport = XMPP::WebSocketTransport.open(ws_config("ws://127.0.0.1:#{fixture.port}/ws"))

    transport.write("<stream:stream to='example.org' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' xml:lang='en' version='1.0'>".to_slice)
    eventually do
      fixture.received_messages.should contain("<open xmlns='urn:ietf:params:xml:ns:xmpp-framing' to='example.org' xml:lang='en' version='1.0'/>")
    end

    buffer = Bytes.new(4096)
    count = transport.read(buffer)
    data = String.new(buffer[0, count])
    data.should start_with("<stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'")
    data.should contain("from='example.org'")
    data.should contain("id='stream-1'")
  ensure
    transport.try(&.close)
    fixture.try(&.close)
  end

  it "round-trips a stanza as a single text message" do
    fixture = WsFixture.new
    transport = XMPP::WebSocketTransport.open(ws_config("ws://127.0.0.1:#{fixture.port}/ws"))

    stanza = "<message to='a@b'><body>hi</body></message>"
    qualified = "<message xmlns=\"jabber:client\" to='a@b'><body>hi</body></message>"
    transport.write(stanza.to_slice)
    buffer = Bytes.new(4096)
    count = transport.read(buffer)
    String.new(buffer[0, count]).should eq qualified
    eventually do
      fixture.received_messages.should contain(qualified)
    end
  ensure
    transport.try(&.close)
    fixture.try(&.close)
  end

  it "sends whitespace keepalives as WebSocket PING frames" do
    fixture = WsFixture.new
    transport = XMPP::WebSocketTransport.open(ws_config("ws://127.0.0.1:#{fixture.port}/ws"))

    transport.write("\n".to_slice)
    select
    when fixture.pinged.receive
    when timeout(2.seconds)
      fail "expected a WebSocket PING frame"
    end
  ensure
    transport.try(&.close)
    fixture.try(&.close)
  end

  it "maps </stream:stream> to <close/> and then reads EOF" do
    fixture = WsFixture.new
    transport = XMPP::WebSocketTransport.open(ws_config("ws://127.0.0.1:#{fixture.port}/ws"))

    transport.write("</stream:stream>".to_slice)
    eventually do
      fixture.received_messages.should contain("<close xmlns='urn:ietf:params:xml:ns:xmpp-framing'/>")
    end
    transport.read(Bytes.new(8)).should eq 0
  ensure
    transport.try(&.close)
    fixture.try(&.close)
  end

  it "rejects a server that does not accept the xmpp subprotocol" do
    fixture = WsFixture.new(subprotocols: nil)
    expect_raises(XMPP::ConnectionError) do
      XMPP::WebSocketTransport.open(ws_config("ws://127.0.0.1:#{fixture.port}/ws"))
    end
  ensure
    fixture.try(&.close)
  end
end
