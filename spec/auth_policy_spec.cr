require "./spec_helper"

module XMPP
  private class AuthTestIO < IO
    getter written = IO::Memory.new

    def initialize(input : String)
      @input = IO::Memory.new(input)
    end

    def read(slice : Bytes) : Int32
      @input.read(slice)
    end

    def write(slice : Bytes) : Nil
      @written.write(slice)
    end
  end

  def self.auth_features(xml : String) : Stanza::StreamFeatures
    node = XML.parse(xml).first_element_child.not_nil!
    Stanza::StreamFeatures.new(node)
  end

  describe AuthHandler do
    it "rejects PLAIN without verified TLS before sending credentials" do
      features = XMPP.auth_features <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
            <mechanism>PLAIN</mechanism>
          </mechanisms>
        </stream:features>
      XML
      io = AuthTestIO.new("")
      handler = AuthHandler.new(
        io,
        XMLStreamReader.new(io),
        features,
        "secret",
        JID.new("romeo@example.org")
      )

      expect_raises(AuthenticationError, /PLAIN authentication requires a verified TLS connection/) do
        handler.authenticate([AuthMechanism::PLAIN])
      end
      io.written.to_s.should be_empty
    end

    it "supports explicitly enabled PLAIN through SASL2 over verified TLS" do
      features = XMPP.auth_features <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>PLAIN</mechanism>
          </authentication>
        </stream:features>
      XML
      io = AuthTestIO.new("<success xmlns='urn:xmpp:sasl:2'><authorization-identifier>romeo@example.org</authorization-identifier></success>")
      handler = AuthHandler.new(
        io,
        XMLStreamReader.new(io),
        features,
        "secret",
        JID.new("romeo@example.org"),
        tls_verified: true
      )

      handler.authenticate([AuthMechanism::PLAIN])

      request = io.written.to_s
      request.should contain("mechanism=\"PLAIN\"")
      request.should contain(Base64.strict_encode("\x00romeo\x00secret"))
    end

    it "falls back from unsupported SASL2 mechanisms to classic SASL" do
      features = XMPP.auth_features <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>DIGEST-MD5</mechanism>
          </authentication>
          <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
            <mechanism>ANONYMOUS</mechanism>
          </mechanisms>
        </stream:features>
      XML
      io = AuthTestIO.new("<success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>")
      handler = AuthHandler.new(
        io,
        XMLStreamReader.new(io),
        features,
        "secret",
        JID.new("romeo@example.org")
      )

      handler.authenticate([AuthMechanism::DIGEST_MD5, AuthMechanism::ANONYMOUS])

      io.written.to_s.should contain("mechanism=\"ANONYMOUS\"")
    end
  end
end
