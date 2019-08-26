require "../../spec_helper"

module XMPP::Stanza
  it "Build a Software version reply" do
    name = "Exodus"
    version = "0.7.0.4"
    os = "Windows-XP 5.01.2600"
    iq = IQ.new
    iq.type = "result"
    iq.from = "romeo@montague.net/orchard"
    iq.to = "juliet@capulet.com/balcony"
    iq.id = "version_1"
    iq.version.set_info(name, version, os)

    # Test to/from XML
    data = iq.to_xml
    parsed = IQ.new data

    pp = parsed.payload
    fail "Parsed stanza does not contain correct IQ payload" if pp.nil? || !pp.is_a?(Version)
    pp = pp.as(Version)
    # Check version info
    pp.name.should eq name
    pp.version.should eq version
    pp.os.should eq os
  end
end
