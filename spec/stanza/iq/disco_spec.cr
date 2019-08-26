require "../../spec_helper"

module XMPP::Stanza
  it "Test DiscoInfo Builder with several features" do
    iq = IQ.new
    iq.type = "get"
    iq.to = "service.localhost"
    iq.id = "disco-get-1"

    disco = iq.disco_info
    disco.add_identity("Test Component", "gateway", "service")
    disco.add_features([XMPP::Stanza::NS_DISCO_INFO, NS_DISCO_ITEMS, "jabber:iq:version", "urn:xmpp:delegation:1"])

    xml = iq.to_xml
    parsed_iq = IQ.new xml

    # Check result
    pp = parsed_iq.payload.as?(DiscoInfo)
    fail "Parsed stanza does not contain correct IQ payload" if pp.nil?
    pp = pp.as(DiscoInfo)

    # Check features
    features = [XMPP::Stanza::NS_DISCO_INFO, NS_DISCO_ITEMS, "jabber:iq:version", "urn:xmpp:delegation:1"]
    features.size.should eq(pp.features.size)

    pp.features.each_with_index do |f, i|
      f.var.should eq(features[i])
    end

    # Check identity
    pp.identity.size.should eq(1)
    pp.identity[0].name.should eq("Test Component")
  end

  it "Implements XEP-0030 example 17 - https://xmpp.org/extensions/xep-0030.html#example-17" do
    iq = IQ.new
    iq.type = "result"
    iq.from = "catalog.shakespeare.lit"
    iq.to = "romeo@montague.net/orchard"
    iq.id = "items-2"

    disco = iq.disco_items
    disco.add_item("catalog.shakespeare.lit", "books", "Books by and about Shakespeare")
    disco.add_item("catalog.shakespeare.lit", "clothing", "Wear your literary taste with pride")
    disco.add_item("catalog.shakespeare.lit", "music", "Music from the time of Shakespeare")

    xml = iq.to_xml
    parsed_iq = IQ.new xml

    # Check result
    pp = parsed_iq.payload.as?(DiscoItems)
    fail "Parsed stanza does not contain correct IQ payload" if pp.nil?
    pp = pp.as(DiscoItems)

    # Check Items
    items = [DiscoItem.new("catalog.shakespeare.lit", "books", "Books by and about Shakespeare"),
             DiscoItem.new("catalog.shakespeare.lit", "clothing", "Wear your literary taste with pride"),
             DiscoItem.new("catalog.shakespeare.lit", "music", "Music from the time of Shakespeare")]

    items.size.should eq(pp.items.size)
    pp.items.each_with_index do |item, i|
      item.jid.should eq(items[i].jid)
      item.node.should eq(items[i].node)
      item.name.should eq(items[i].name)
    end
  end
end
