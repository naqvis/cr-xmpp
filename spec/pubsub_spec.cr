require "./spec_helper"
require "../src/xmpp/stanza/pubsub"

describe XMPP::Stanza::PubSub do
  describe "Subscribe" do
    it "parses subscribe element" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <subscribe node='princely_musings' jid='francisco@denmark.lit'/>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      pubsub.subscribe.should_not be_nil
      subscribe = pubsub.subscribe.not_nil!
      subscribe.node.should eq("princely_musings")
      subscribe.jid.should eq("francisco@denmark.lit")
    end

    it "generates subscribe element" do
      pubsub = XMPP::Stanza::PubSub.new
      subscribe = XMPP::Stanza::Subscribe.new
      subscribe.node = "princely_musings"
      subscribe.jid = "francisco@denmark.lit"
      pubsub.subscribe = subscribe

      xml = XML.build { |x| pubsub.to_xml(x) }
      xml.should contain("subscribe")
      xml.should contain("node=\"princely_musings\"")
      xml.should contain("jid=\"francisco@denmark.lit\"")
    end
  end

  describe "Unsubscribe" do
    it "parses unsubscribe element" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <unsubscribe node='princely_musings' jid='francisco@denmark.lit' subid='ba49252aaa4f5d320c24d3766f0bdcade78c78d3'/>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      pubsub.unsubscribe.should_not be_nil
      unsubscribe = pubsub.unsubscribe.not_nil!
      unsubscribe.node.should eq("princely_musings")
      unsubscribe.jid.should eq("francisco@denmark.lit")
      unsubscribe.subid.should eq("ba49252aaa4f5d320c24d3766f0bdcade78c78d3")
    end

    it "generates unsubscribe element" do
      pubsub = XMPP::Stanza::PubSub.new
      unsubscribe = XMPP::Stanza::Unsubscribe.new
      unsubscribe.node = "princely_musings"
      unsubscribe.jid = "francisco@denmark.lit"
      unsubscribe.subid = "ba49252aaa4f5d320c24d3766f0bdcade78c78d3"
      pubsub.unsubscribe = unsubscribe

      xml = XML.build { |x| pubsub.to_xml(x) }
      xml.should contain("unsubscribe")
      xml.should contain("node=\"princely_musings\"")
      xml.should contain("jid=\"francisco@denmark.lit\"")
      xml.should contain("subid=\"ba49252aaa4f5d320c24d3766f0bdcade78c78d3\"")
    end
  end

  describe "Subscription" do
    it "parses subscription element with subscribed state" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <subscription node='princely_musings' jid='francisco@denmark.lit' subscription='subscribed' subid='ba49252aaa4f5d320c24d3766f0bdcade78c78d3'/>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      pubsub.subscription.should_not be_nil
      subscription = pubsub.subscription.not_nil!
      subscription.node.should eq("princely_musings")
      subscription.jid.should eq("francisco@denmark.lit")
      subscription.subscription.should eq("subscribed")
      subscription.subid.should eq("ba49252aaa4f5d320c24d3766f0bdcade78c78d3")
    end

    it "parses subscription element with pending state" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <subscription node='princely_musings' jid='francisco@denmark.lit' subscription='pending'/>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      subscription = pubsub.subscription.not_nil!
      subscription.subscription.should eq("pending")
    end

    it "generates subscription element" do
      pubsub = XMPP::Stanza::PubSub.new
      subscription = XMPP::Stanza::Subscription.new
      subscription.node = "princely_musings"
      subscription.jid = "francisco@denmark.lit"
      subscription.subscription = "subscribed"
      subscription.subid = "ba49252aaa4f5d320c24d3766f0bdcade78c78d3"
      pubsub.subscription = subscription

      xml = XML.build { |x| pubsub.to_xml(x) }
      xml.should contain("subscription")
      xml.should contain("subscription=\"subscribed\"")
    end
  end

  describe "Subscriptions" do
    it "parses subscriptions list" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <subscriptions>
            <subscription node='node1' jid='francisco@denmark.lit' subscription='subscribed'/>
            <subscription node='node2' jid='francisco@denmark.lit' subscription='pending'/>
            <subscription node='node3' jid='francisco@denmark.lit' subscription='unconfigured'/>
          </subscriptions>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      pubsub.subscriptions.should_not be_nil
      subscriptions = pubsub.subscriptions.not_nil!
      subscriptions.subscriptions.size.should eq(3)
      subscriptions.subscriptions[0].node.should eq("node1")
      subscriptions.subscriptions[0].subscription.should eq("subscribed")
      subscriptions.subscriptions[1].node.should eq("node2")
      subscriptions.subscriptions[1].subscription.should eq("pending")
      subscriptions.subscriptions[2].node.should eq("node3")
      subscriptions.subscriptions[2].subscription.should eq("unconfigured")
    end

    it "generates subscriptions list" do
      pubsub = XMPP::Stanza::PubSub.new
      subscriptions = XMPP::Stanza::Subscriptions.new

      sub1 = XMPP::Stanza::Subscription.new
      sub1.node = "node1"
      sub1.jid = "francisco@denmark.lit"
      sub1.subscription = "subscribed"

      sub2 = XMPP::Stanza::Subscription.new
      sub2.node = "node2"
      sub2.jid = "francisco@denmark.lit"
      sub2.subscription = "pending"

      subscriptions.subscriptions = [sub1, sub2]
      pubsub.subscriptions = subscriptions

      xml = XML.build { |x| pubsub.to_xml(x) }
      xml.should contain("subscriptions")
      xml.should contain("node=\"node1\"")
      xml.should contain("node=\"node2\"")
    end
  end

  describe "Affiliations" do
    it "parses affiliations list" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <affiliations>
            <affiliation node='node1' jid='francisco@denmark.lit' affiliation='owner'/>
            <affiliation node='node2' jid='francisco@denmark.lit' affiliation='publisher'/>
            <affiliation node='node3' jid='francisco@denmark.lit' affiliation='member'/>
            <affiliation node='node4' jid='francisco@denmark.lit' affiliation='outcast'/>
          </affiliations>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      pubsub.affiliations.should_not be_nil
      affiliations = pubsub.affiliations.not_nil!
      affiliations.affiliations.size.should eq(4)
      affiliations.affiliations[0].node.should eq("node1")
      affiliations.affiliations[0].affiliation.should eq("owner")
      affiliations.affiliations[1].node.should eq("node2")
      affiliations.affiliations[1].affiliation.should eq("publisher")
      affiliations.affiliations[2].node.should eq("node3")
      affiliations.affiliations[2].affiliation.should eq("member")
      affiliations.affiliations[3].node.should eq("node4")
      affiliations.affiliations[3].affiliation.should eq("outcast")
    end

    it "generates affiliations list" do
      pubsub = XMPP::Stanza::PubSub.new
      affiliations = XMPP::Stanza::Affiliations.new

      aff1 = XMPP::Stanza::Affiliation.new
      aff1.node = "node1"
      aff1.jid = "francisco@denmark.lit"
      aff1.affiliation = "owner"

      aff2 = XMPP::Stanza::Affiliation.new
      aff2.node = "node2"
      aff2.jid = "francisco@denmark.lit"
      aff2.affiliation = "publisher"

      affiliations.affiliations = [aff1, aff2]
      pubsub.affiliations = affiliations

      xml = XML.build { |x| pubsub.to_xml(x) }
      xml.should contain("affiliations")
      xml.should contain("affiliation=\"owner\"")
      xml.should contain("affiliation=\"publisher\"")
    end
  end

  describe "Items" do
    it "parses items request" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <items node='princely_musings' max_items='10'/>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      pubsub.items.should_not be_nil
      items = pubsub.items.not_nil!
      items.node.should eq("princely_musings")
      items.max_items.should eq("10")
    end

    it "parses items response with multiple items" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <items node='princely_musings'>
            <item id='368866411b877c30064a5f62b917cffe'/>
            <item id='3300659945416e274474e469a1f0154c'/>
            <item id='4e30f35051b7b8b42abe083742187228'/>
          </items>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      items = pubsub.items.not_nil!
      items.items.size.should eq(3)
      items.items[0].id.should eq("368866411b877c30064a5f62b917cffe")
      items.items[1].id.should eq("3300659945416e274474e469a1f0154c")
      items.items[2].id.should eq("4e30f35051b7b8b42abe083742187228")
    end

    it "generates items request" do
      pubsub = XMPP::Stanza::PubSub.new
      items = XMPP::Stanza::Items.new
      items.node = "princely_musings"
      items.max_items = "10"
      pubsub.items = items

      xml = XML.build { |x| pubsub.to_xml(x) }
      xml.should contain("items")
      xml.should contain("node=\"princely_musings\"")
      xml.should contain("max_items=\"10\"")
    end

    it "generates items response with items" do
      pubsub = XMPP::Stanza::PubSub.new
      items = XMPP::Stanza::Items.new
      items.node = "princely_musings"

      item1 = XMPP::Stanza::Item.new
      item1.id = "item1"
      item2 = XMPP::Stanza::Item.new
      item2.id = "item2"

      items.items = [item1, item2]
      pubsub.items = items

      xml = XML.build { |x| pubsub.to_xml(x) }
      xml.should contain("id=\"item1\"")
      xml.should contain("id=\"item2\"")
    end
  end

  describe "Publish and Retract (existing functionality)" do
    it "parses publish element" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='princely_musings'>
            <item id='bnd81g37d61f49fgn581'/>
          </publish>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      pubsub.publish.should_not be_nil
      publish = pubsub.publish.not_nil!
      publish.node.should eq("princely_musings")
      publish.item.should_not be_nil
      publish.item.not_nil!.id.should eq("bnd81g37d61f49fgn581")
    end

    it "parses retract element" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <retract node='princely_musings' notify='true'>
            <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
          </retract>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      pubsub.retract.should_not be_nil
      retract = pubsub.retract.not_nil!
      retract.node.should eq("princely_musings")
      retract.notify.should eq("true")
      retract.item.should_not be_nil
      retract.item.not_nil!.id.should eq("ae890ac52d0df67ed7cfdf51b644e901")
    end
  end

  describe "Integration with PEP" do
    it "parses item with tune payload" do
      xml = <<-XML
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <items node='http://jabber.org/protocol/tune'>
            <item id='current'>
              <tune xmlns='http://jabber.org/protocol/tune'>
                <artist>The Beatles</artist>
                <title>Hey Jude</title>
              </tune>
            </item>
          </items>
        </pubsub>
      XML

      pubsub = XMPP::Stanza::PubSub.new(xml)
      items = pubsub.items.not_nil!
      items.items.size.should eq(1)
      item = items.items[0]
      item.id.should eq("current")
      item.tune.should_not be_nil
      tune = item.tune.not_nil!
      tune.artist.should eq("The Beatles")
      tune.title.should eq("Hey Jude")
    end
  end
end
