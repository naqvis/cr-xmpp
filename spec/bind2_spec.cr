require "./spec_helper"

describe "XEP-0386: Bind 2" do
  it "parses Bind 2 discovery and advertised inline features" do
    xml = <<-XML
      <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
        <authentication xmlns='urn:xmpp:sasl:2'>
          <mechanism>SCRAM-SHA-256</mechanism>
          <inline>
            <bind xmlns='urn:xmpp:bind:0'>
              <inline>
                <feature var='urn:xmpp:carbons:2'/>
                <feature var='urn:xmpp:csi:0'/>
                <feature var='urn:xmpp:sm:3'/>
              </inline>
            </bind>
          </inline>
        </authentication>
      </stream:features>
    XML

    features = XMPP::Stanza::StreamFeatures.new(XML.parse(xml).first_element_child.not_nil!)
    sasl2 = features.sasl2_authentication.not_nil!
    bind2 = sasl2.bind2.not_nil!

    sasl2.supports_bind2?.should be_true
    bind2.features.should eq ["urn:xmpp:carbons:2", "urn:xmpp:csi:0", "urn:xmpp:sm:3"]
    bind2.supports?("urn:xmpp:sm:3").should be_true

    serialized = features.to_xml
    serialized.should contain("<bind xmlns=\"urn:xmpp:bind:0\">")
    serialized.should contain("<feature var=\"urn:xmpp:carbons:2\"/>")
  end

  it "parses and serializes a bind request with extensible session features" do
    xml = <<-XML
      <bind xmlns='urn:xmpp:bind:0'>
        <tag>AwesomeXMPP</tag>
        <enable xmlns='urn:xmpp:carbons:2'/>
        <enable xmlns='urn:xmpp:sm:3' resume='true'/>
        <inactive xmlns='urn:xmpp:csi:0'/>
      </bind>
    XML

    request = XMPP::Stanza::Bind2Request.new(XML.parse(xml).first_element_child.not_nil!)

    request.tag.should eq "AwesomeXMPP"
    request.features.map(&.namespace).should eq [
      "urn:xmpp:carbons:2",
      "urn:xmpp:sm:3",
      "urn:xmpp:csi:0",
    ]

    serialized = XML.build { |builder| request.to_xml(builder) }
    serialized.should contain("<tag>AwesomeXMPP</tag>")
    serialized.should contain("<enable resume=\"true\" xmlns=\"urn:xmpp:sm:3\"/>")
  end

  it "parses a bound result and preserves extension responses" do
    xml = <<-XML
      <success xmlns='urn:xmpp:sasl:2'>
        <authorization-identifier>user@example.com/AwesomeXMPP.4232f4d4</authorization-identifier>
        <bound xmlns='urn:xmpp:bind:0'>
          <metadata xmlns='urn:xmpp:mam:2'>
            <start id='YWxwaGEg' timestamp='2008-08-22T21:09:04Z'/>
            <end id='b21lZ2Eg' timestamp='2020-04-20T14:34:21Z'/>
          </metadata>
          <enabled xmlns='urn:xmpp:sm:3' id='stream-id' resume='true'/>
        </bound>
      </success>
    XML

    success = XMPP::Stanza::SASL2Success.new(XML.parse(xml).first_element_child.not_nil!)
    bound = success.bound.not_nil!

    success.authorization_identifier.should eq "user@example.com/AwesomeXMPP.4232f4d4"
    bound.features.size.should eq 2
    bound.feature("urn:xmpp:mam:2").should_not be_nil
    bound.feature("urn:xmpp:sm:3").not_nil!.attrs["id"].should eq "stream-id"

    serialized = success.to_xml
    serialized.should contain("<bound xmlns=\"urn:xmpp:bind:0\">")
    serialized.should contain("<metadata xmlns=\"urn:xmpp:mam:2\">")
  end
end

module XMPP
  private class Bind2AuthTestIO < IO
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

  describe AuthHandler do
    it "performs Bind 2 inline with SASL2 and exposes the assigned JID" do
      features_xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>PLAIN</mechanism>
            <inline><bind xmlns='urn:xmpp:bind:0'/></inline>
          </authentication>
        </stream:features>
      XML
      success_xml = <<-XML
        <success xmlns='urn:xmpp:sasl:2'>
          <authorization-identifier>romeo@example.org/Crystal-XMPP/server-id</authorization-identifier>
          <bound xmlns='urn:xmpp:bind:0'/>
        </success>
      XML
      io = Bind2AuthTestIO.new(success_xml)
      features = Stanza::StreamFeatures.new(XML.parse(features_xml).first_element_child.not_nil!)
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
      request.should contain("<bind xmlns=\"urn:xmpp:bind:0\">")
      request.should contain("<tag>Crystal-XMPP</tag>")
      handler.bound_jid.should eq "romeo@example.org/Crystal-XMPP/server-id"
      handler.used_sasl2?.should be_true
    end

    it "rejects a SASL2 success that omits the requested bound result" do
      features_xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>PLAIN</mechanism>
            <inline><bind xmlns='urn:xmpp:bind:0'/></inline>
          </authentication>
        </stream:features>
      XML
      io = Bind2AuthTestIO.new(
        "<success xmlns='urn:xmpp:sasl:2'>" \
        "<authorization-identifier>romeo@example.org/assigned</authorization-identifier>" \
        "</success>"
      )
      features = Stanza::StreamFeatures.new(XML.parse(features_xml).first_element_child.not_nil!)
      handler = AuthHandler.new(
        io,
        XMLStreamReader.new(io),
        features,
        "secret",
        JID.new("romeo@example.org"),
        tls_verified: true
      )

      expect_raises(AuthenticationError, /omitted the Bind 2 bound response/) do
        handler.authenticate([AuthMechanism::PLAIN])
      end
    end

    it "rejects a bound response without a full authorization identifier" do
      features_xml = <<-XML
        <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
          <authentication xmlns='urn:xmpp:sasl:2'>
            <mechanism>PLAIN</mechanism>
            <inline><bind xmlns='urn:xmpp:bind:0'/></inline>
          </authentication>
        </stream:features>
      XML
      io = Bind2AuthTestIO.new(
        "<success xmlns='urn:xmpp:sasl:2'>" \
        "<authorization-identifier>romeo@example.org</authorization-identifier>" \
        "<bound xmlns='urn:xmpp:bind:0'/>" \
        "</success>"
      )
      features = Stanza::StreamFeatures.new(XML.parse(features_xml).first_element_child.not_nil!)
      handler = AuthHandler.new(
        io,
        XMLStreamReader.new(io),
        features,
        "secret",
        JID.new("romeo@example.org"),
        tls_verified: true
      )

      expect_raises(AuthenticationError, /did not assign a resource/) do
        handler.authenticate([AuthMechanism::PLAIN])
      end
    end
  end
end
