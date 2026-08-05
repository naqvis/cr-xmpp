require "./spec_helper"
require "http/server"

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

private def bosh_config(url : String) : XMPP::Config
  XMPP::Config.new(
    jid: "test@example.org/bosh",
    password: "secret",
    host: "example.org",
    transport: XMPP::TransportMode::Bosh,
    url: url,
    tls: true
  )
end

private class BoshFixture
  getter requests = [] of String
  getter server : HTTP::Server
  getter port : Int32

  @requests_mutex = Mutex.new

  def initialize
    @server = HTTP::Server.new do |ctx|
      body = ctx.request.body.try(&.gets_to_end) || ""
      @requests_mutex.synchronize { @requests << body }
      root = XML.parse(body).first_element_child.not_nil!
      sid = root["sid"]?
      type = root["type"]?
      restart = root["restart"]?
      respond = ->(content : String) do
        ctx.response.content_type = "text/xml; charset=utf-8"
        ctx.response.print content
      end

      if type == "terminate"
        respond.call("<body xmlns='http://jabber.org/protocol/httpbind' rid='#{root["rid"]}' sid='#{sid}' type='terminate'/>")
      elsif sid.nil?
        respond.call("<body xmlns='http://jabber.org/protocol/httpbind' rid='#{root["rid"]}' sid='bosh-session-1'><stream:features xmlns='http://etherx.jabber.org/streams'><mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><mechanism>PLAIN</mechanism></mechanisms></stream:features></body>")
      elsif restart
        respond.call("<body xmlns='http://jabber.org/protocol/httpbind' rid='#{root["rid"]}' sid='#{sid}'><stream:features xmlns='http://etherx.jabber.org/streams'/></body>")
      else
        children = root.children.select(&.element?).map(&.to_s).join
        respond.call("<body xmlns='http://jabber.org/protocol/httpbind' rid='#{root["rid"]}' sid='#{sid}'>#{children}</body>")
      end
    end
    address = @server.bind_tcp "127.0.0.1", 0
    @port = address.port
    spawn { @server.listen }
  end

  def body_count
    @requests_mutex.synchronize { @requests.size }
  end

  def close
    @server.close
  end
end

private def rid_of(body : String) : String?
  XMPP::Transport.extract_attribute(body, "rid")
end

private STREAM_OPEN = "<stream:stream to='example.org' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' xml:lang='en' version='1.0'>"

describe XMPP::BoshTransport do
  it "creates a BOSH session on the first read and synthesizes the stream header" do
    fixture = BoshFixture.new
    transport = XMPP::BoshTransport.open(bosh_config("http://127.0.0.1:#{fixture.port}/http-bind"))

    transport.write(STREAM_OPEN.to_slice)
    eventually { fixture.body_count.should eq 0 } # header write alone does not POST

    buffer = Bytes.new(4096)
    count = transport.read(buffer)
    data = String.new(buffer[0, count])
    data.should start_with("<stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
    data.should contain("<stream:features")

    create_body = fixture.requests.first
    create_body.should contain("xmlns='http://jabber.org/protocol/httpbind'")
    create_body.should contain("rid=")
    create_body.should contain("to='example.org'")
    create_body.should contain("wait='1'")
    create_body.should contain("xmpp:version='1.0'")
    create_body.should_not contain("stream:stream")
  ensure
    transport.try(&.close)
    fixture.try(&.close)
  end

  it "captures sid and flushes queued stanzas in the next request, incrementing rid" do
    fixture = BoshFixture.new
    transport = XMPP::BoshTransport.open(bosh_config("http://127.0.0.1:#{fixture.port}/http-bind"))

    transport.write(STREAM_OPEN.to_slice)
    transport.read(Bytes.new(4096)) # create session

    stanza = "<presence id='p1'/>"
    transport.write(stanza.to_slice)
    buffer = Bytes.new(4096)
    count = transport.read(buffer)
    result = String.new(buffer[0, count])
    result.should contain("<presence")
    result.should contain("p1")

    flush_body = fixture.requests[1]
    flush_body.should contain(stanza)
    flush_body.should contain("sid='bosh-session-1'")

    rid1 = rid_of(fixture.requests[0]).not_nil!.to_u32
    rid2 = rid_of(fixture.requests[1]).not_nil!.to_u32
    rid2.should eq(rid1 + 1)
  ensure
    transport.try(&.close)
    fixture.try(&.close)
  end

  it "sends a stream restart as xmpp:restart='true'" do
    fixture = BoshFixture.new
    transport = XMPP::BoshTransport.open(bosh_config("http://127.0.0.1:#{fixture.port}/http-bind"))

    transport.write(STREAM_OPEN.to_slice)
    transport.read(Bytes.new(4096)) # create session

    transport.write(STREAM_OPEN.to_slice)
    transport.read(Bytes.new(4096)) # flush restart

    restart_body = fixture.requests[1]
    restart_body.should contain("xmpp:restart='true'")
    restart_body.should_not contain("stream:stream")
  ensure
    transport.try(&.close)
    fixture.try(&.close)
  end

  it "terminates the session on </stream:stream> and reaches EOF" do
    fixture = BoshFixture.new
    transport = XMPP::BoshTransport.open(bosh_config("http://127.0.0.1:#{fixture.port}/http-bind"))

    transport.write(STREAM_OPEN.to_slice)
    transport.read(Bytes.new(4096)) # create session

    transport.write("</stream:stream>".to_slice)
    transport.read(Bytes.new(4096)).should eq 0

    terminate_body = fixture.requests[1]
    terminate_body.should contain("type='terminate'")
  ensure
    transport.try(&.close)
    fixture.try(&.close)
  end

  it "raises ProtocolError when the session-create response lacks a sid" do
    server = HTTP::Server.new do |ctx|
      ctx.response.content_type = "text/xml; charset=utf-8"
      ctx.response.print "<body xmlns='http://jabber.org/protocol/httpbind' rid='1'/>"
    end
    address = server.bind_tcp "127.0.0.1", 0
    spawn { server.listen }

    transport = XMPP::BoshTransport.open(bosh_config("http://127.0.0.1:#{address.port}/http-bind"))
    transport.write(STREAM_OPEN.to_slice)
    expect_raises(XMPP::ProtocolError, /sid/) do
      transport.read(Bytes.new(4096))
    end
  ensure
    transport.try(&.close)
    server.try(&.close)
  end
end
