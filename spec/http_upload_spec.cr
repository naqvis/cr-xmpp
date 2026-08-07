require "./spec_helper"
require "../src/xmpp/stanza/iq/http_upload"
require "http/server"

private class HTTPUploadStubClient < XMPP::Client
  getter requested : Array(XMPP::Stanza::IQ) = [] of XMPP::Stanza::IQ
  property response : XMPP::Stanza::IQ? = nil

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def request(iq : XMPP::Stanza::IQ, timeout : Time::Span = 5.seconds) : XMPP::Stanza::IQ?
    @requested << iq
    @response
  end

  def bare_jid : String
    "test@localhost"
  end
end

describe XMPP::Stanza::UploadRequest do
  it "parses a request" do
    req = XMPP::Stanza::UploadRequest.new(<<-XML)
      <request xmlns='urn:xmpp:http:upload:0'
               filename='trillian.jpg'
               size='23456'
               content-type='image/jpeg'/>
      XML

    req.filename.should eq "trillian.jpg"
    req.size.should eq 23456_u64
    req.content_type.should eq "image/jpeg"
  end

  it "serializes a request" do
    req = XMPP::Stanza::UploadRequest.new
    req.filename = "trillian.jpg"
    req.size = 23456_u64
    req.content_type = "image/jpeg"

    xml = XML.build { |x| req.to_xml(x) }
    xml.should contain("urn:xmpp:http:upload:0")
    xml.should contain("filename=\"trillian.jpg\"")
    xml.should contain("size=\"23456\"")
    xml.should contain("content-type=\"image/jpeg\"")
  end
end

describe XMPP::Stanza::Slot do
  it "parses a slot with put headers" do
    slot = XMPP::Stanza::Slot.new(<<-XML)
      <slot xmlns='urn:xmpp:http:upload:0'>
        <put url='https://upload.example.org/a4f1/put'>
          <header name='Authorization'>Bearer abc</header>
        </put>
        <get url='https://upload.example.org/a4f1/get'/>
      </slot>
      XML

    slot.put_url.should eq "https://upload.example.org/a4f1/put"
    slot.get_url.should eq "https://upload.example.org/a4f1/get"
    header = slot.put_headers.first
    header.name.should eq "Authorization"
    header.value.should eq "Bearer abc"
  end

  it "serializes a slot" do
    slot = XMPP::Stanza::Slot.new
    slot.put_url = "https://upload.example.org/a4f1/put"
    slot.get_url = "https://upload.example.org/a4f1/get"

    xml = XML.build { |x| slot.to_xml(x) }
    xml.should contain("urn:xmpp:http:upload:0")
    xml.should contain("url=\"https://upload.example.org/a4f1/put\"")
    xml.should contain("url=\"https://upload.example.org/a4f1/get\"")
  end
end

describe XMPP::HTTPUpload do
  it "request_slot sends an IQ-get to the service" do
    client = HTTPUploadStubClient.new
    slot = XMPP::Stanza::Slot.new
    slot.put_url = "https://upload.example.org/put"
    slot.get_url = "https://upload.example.org/get"
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = slot
    client.response = result

    response = XMPP::HTTPUpload.new(client, "upload.example.org")
      .request_slot("trillian.jpg", 23456_u64, "image/jpeg")

    response.should be slot
    iq = client.requested.first
    iq.type.should eq "get"
    iq.to.should eq "upload.example.org"
    req = iq.payload.as(XMPP::Stanza::UploadRequest)
    req.filename.should eq "trillian.jpg"
    req.size.should eq 23456_u64
  end

  it "supported? is true when disco advertises urn:xmpp:http:upload:0" do
    client = HTTPUploadStubClient.new
    info = XMPP::Stanza::DiscoInfo.new
    feature = XMPP::Stanza::Feature.new
    feature.var = "urn:xmpp:http:upload:0"
    info.features << feature
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = info
    client.response = result

    XMPP::HTTPUpload.new(client, "upload.example.org").supported?.should be_true
  end

  it "upload PUTs the data and returns the GET URL" do
    probe = TCPServer.new("127.0.0.1", 0)
    port = probe.local_address.port
    probe.close

    received = Channel(String).new(1)
    server = HTTP::Server.new do |ctx|
      received.send(ctx.request.body.try(&.gets_to_end) || "")
      ctx.response.status = HTTP::Status::CREATED
    end
    server.bind_tcp "127.0.0.1", port
    spawn { server.listen }

    begin
      slot = XMPP::Stanza::Slot.new
      slot.put_url = "http://127.0.0.1:#{port}/upload"
      slot.get_url = "http://127.0.0.1:#{port}/file"
      client = HTTPUploadStubClient.new
      result = XMPP::Stanza::IQ.new
      result.type = "result"
      result.payload = slot
      client.response = result

      url = XMPP::HTTPUpload.new(client, "upload.example.org")
        .upload("file.txt", 5_u64, "text/plain", "hello")

      url.should eq "http://127.0.0.1:#{port}/file"
      received.receive.should eq "hello"
    ensure
      server.close
    end
  end
end
