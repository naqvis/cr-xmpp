require "../spec_helper"

describe XMPP::Stanza::CSIActive do
  it "serializes to the empty active nonza" do
    XMPP::Stanza::CSIActive.new.to_xml.should eq %(<active xmlns="urn:xmpp:csi:0"/>\n)
  end

  it "parses a matching element" do
    doc = XML.parse(%(<active xmlns="urn:xmpp:csi:0"/>))
    node = doc.first_element_child.not_nil!
    stanza = XMPP::Stanza::CSIActive.new(node)
    stanza.name.should eq "active"
  end

  it "rejects a non-active element" do
    doc = XML.parse(%(<inactive xmlns="urn:xmpp:csi:0"/>))
    node = doc.first_element_child.not_nil!
    expect_raises(Exception) { XMPP::Stanza::CSIActive.new(node) }
  end
end

describe XMPP::Stanza::CSIInactive do
  it "serializes to the empty inactive nonza" do
    XMPP::Stanza::CSIInactive.new.to_xml.should eq %(<inactive xmlns="urn:xmpp:csi:0"/>\n)
  end

  it "parses a matching element" do
    doc = XML.parse(%(<inactive xmlns="urn:xmpp:csi:0"/>))
    node = doc.first_element_child.not_nil!
    stanza = XMPP::Stanza::CSIInactive.new(node)
    stanza.name.should eq "inactive"
  end

  it "rejects a non-inactive element" do
    doc = XML.parse(%(<active xmlns="urn:xmpp:csi:0"/>))
    node = doc.first_element_child.not_nil!
    expect_raises(Exception) { XMPP::Stanza::CSIInactive.new(node) }
  end
end
