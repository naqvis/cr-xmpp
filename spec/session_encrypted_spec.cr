require "./spec_helper"

private class ScriptedIO < ::IO
  getter transcript : String

  def initialize(@responses : Array(String))
    @buffer = IO::Memory.new
    @index = 0
    @transcript = ""
  end

  def read(slice : Bytes) : Int32
    while @buffer.pos >= @buffer.size && @index < @responses.size
      @buffer.write(@responses[@index].to_slice)
      @buffer.rewind
      @index += 1
    end
    if @buffer.pos < @buffer.size
      @buffer.read(slice)
    else
      0
    end
  end

  def write(slice : Bytes) : Nil
    @transcript += String.new(slice)
  end
end

private def session_config : XMPP::Config
  XMPP::Config.new(
    jid: "test@example.org/res",
    password: "secret",
    host: "example.org",
    sasl_auth_order: [XMPP::AuthMechanism::PLAIN]
  )
end

private STREAM_HEADER   = "<stream:stream xmlns:stream='http://etherx.jabber.org/streams' xmlns='jabber:client' to='example.org' id='stream-1'>"
private STREAM_FEATURES = "<stream:features xmlns='http://etherx.jabber.org/streams'><starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/><mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><mechanism>PLAIN</mechanism></mechanisms></stream:features>"
private TLS_PROCEED     = "<proceed xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>"

describe XMPP::Session do
  it "skips STARTTLS when the transport is already encrypted" do
    scripted = ScriptedIO.new([STREAM_HEADER, STREAM_FEATURES])
    begin
      XMPP::Session.new(scripted, session_config, XMPP::SMState.new, encrypted: true)
    rescue XMPP::AuthenticationError
      # PLAIN requires verified TLS; not reaching it is the point of this test.
    end
    scripted.transcript.should_not contain("urn:ietf:params:xml:ns:xmpp-tls")
    scripted.transcript.should contain("<stream:stream to='example.org'")
  end

  it "attempts STARTTLS when the transport is not pre-encrypted" do
    scripted = ScriptedIO.new([STREAM_HEADER, STREAM_FEATURES, TLS_PROCEED])
    begin
      XMPP::Session.new(scripted, session_config, XMPP::SMState.new, encrypted: false)
    rescue ex : XMPP::ConnectionError | XMPP::PermanentConnectionError | IO::Error
      # TLS wrap of the scripted IO legitimately fails; the <starttls/> write
      # already happened and is what we assert on.
    end
    scripted.transcript.should contain("<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>")
  end
end
