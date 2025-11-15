require "../src/xmpp"

# # XEP-0060: Publish-Subscribe Example
#
# This example demonstrates the enhanced PubSub implementation including:
# - Subscribing to nodes
# - Unsubscribing from nodes
# - Retrieving subscriptions
# - Retrieving affiliations
# - Retrieving items from nodes
# - Publishing and retracting items

module PubSubExample
  # Example 1: Subscribe to a node
  def self.subscribe_to_node
    puts "\n=== Subscribe to Node ==="

    iq = XMPP::Stanza::IQ.new
    iq.type = "set"
    iq.from = "francisco@denmark.lit/barracks"
    iq.to = "pubsub.shakespeare.lit"
    iq.id = "sub1"

    pubsub = XMPP::Stanza::PubSub.new
    subscribe = XMPP::Stanza::Subscribe.new
    subscribe.node = "princely_musings"
    subscribe.jid = "francisco@denmark.lit"
    pubsub.subscribe = subscribe

    iq.payload = pubsub

    puts iq.to_xml
  end

  # Example 2: Unsubscribe from a node
  def self.unsubscribe_from_node
    puts "\n=== Unsubscribe from Node ==="

    iq = XMPP::Stanza::IQ.new
    iq.type = "set"
    iq.from = "francisco@denmark.lit/barracks"
    iq.to = "pubsub.shakespeare.lit"
    iq.id = "unsub1"

    pubsub = XMPP::Stanza::PubSub.new
    unsubscribe = XMPP::Stanza::Unsubscribe.new
    unsubscribe.node = "princely_musings"
    unsubscribe.jid = "francisco@denmark.lit"
    unsubscribe.subid = "ba49252aaa4f5d320c24d3766f0bdcade78c78d3"
    pubsub.unsubscribe = unsubscribe

    iq.payload = pubsub

    puts iq.to_xml
  end

  # Example 3: Retrieve all subscriptions
  def self.retrieve_subscriptions
    puts "\n=== Retrieve Subscriptions ==="

    iq = XMPP::Stanza::IQ.new
    iq.type = "get"
    iq.from = "francisco@denmark.lit/barracks"
    iq.to = "pubsub.shakespeare.lit"
    iq.id = "subscriptions1"

    pubsub = XMPP::Stanza::PubSub.new
    subscriptions = XMPP::Stanza::Subscriptions.new
    pubsub.subscriptions = subscriptions

    iq.payload = pubsub

    puts iq.to_xml
  end

  # Example 4: Parse subscription response
  def self.parse_subscription_response
    puts "\n=== Parse Subscription Response ==="

    xml = <<-XML
      <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='subscriptions1'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <subscriptions>
            <subscription node='node1' jid='francisco@denmark.lit' subscription='subscribed' subid='123abc'/>
            <subscription node='node2' jid='francisco@denmark.lit' subscription='pending'/>
            <subscription node='node3' jid='francisco@denmark.lit' subscription='unconfigured'/>
          </subscriptions>
        </pubsub>
      </iq>
    XML

    iq = XMPP::Stanza::IQ.new(xml)
    pubsub = iq.payload.as(XMPP::Stanza::PubSub)

    if subs = pubsub.subscriptions
      puts "Found #{subs.subscriptions.size} subscriptions:"
      subs.subscriptions.each do |sub|
        puts "  - Node: #{sub.node}, State: #{sub.subscription}, SubID: #{sub.subid}"
      end
    end
  end

  # Example 5: Retrieve affiliations
  def self.retrieve_affiliations
    puts "\n=== Retrieve Affiliations ==="

    iq = XMPP::Stanza::IQ.new
    iq.type = "get"
    iq.from = "francisco@denmark.lit/barracks"
    iq.to = "pubsub.shakespeare.lit"
    iq.id = "affil1"

    pubsub = XMPP::Stanza::PubSub.new
    affiliations = XMPP::Stanza::Affiliations.new
    pubsub.affiliations = affiliations

    iq.payload = pubsub

    puts iq.to_xml
  end

  # Example 6: Parse affiliation response
  def self.parse_affiliation_response
    puts "\n=== Parse Affiliation Response ==="

    xml = <<-XML
      <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='affil1'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <affiliations>
            <affiliation node='node1' jid='francisco@denmark.lit' affiliation='owner'/>
            <affiliation node='node2' jid='francisco@denmark.lit' affiliation='publisher'/>
            <affiliation node='node3' jid='francisco@denmark.lit' affiliation='member'/>
            <affiliation node='node4' jid='francisco@denmark.lit' affiliation='outcast'/>
          </affiliations>
        </pubsub>
      </iq>
    XML

    iq = XMPP::Stanza::IQ.new(xml)
    pubsub = iq.payload.as(XMPP::Stanza::PubSub)

    if affils = pubsub.affiliations
      puts "Found #{affils.affiliations.size} affiliations:"
      affils.affiliations.each do |affil|
        puts "  - Node: #{affil.node}, Affiliation: #{affil.affiliation}"
      end
    end
  end

  # Example 7: Retrieve items from a node
  def self.retrieve_items
    puts "\n=== Retrieve Items ==="

    iq = XMPP::Stanza::IQ.new
    iq.type = "get"
    iq.from = "francisco@denmark.lit/barracks"
    iq.to = "pubsub.shakespeare.lit"
    iq.id = "items1"

    pubsub = XMPP::Stanza::PubSub.new
    items = XMPP::Stanza::Items.new
    items.node = "princely_musings"
    items.max_items = "10"
    pubsub.items = items

    iq.payload = pubsub

    puts iq.to_xml
  end

  # Example 8: Parse items response
  def self.parse_items_response
    puts "\n=== Parse Items Response ==="

    xml = <<-XML
      <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='items1'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <items node='princely_musings'>
            <item id='368866411b877c30064a5f62b917cffe'/>
            <item id='3300659945416e274474e469a1f0154c'/>
            <item id='4e30f35051b7b8b42abe083742187228'/>
          </items>
        </pubsub>
      </iq>
    XML

    iq = XMPP::Stanza::IQ.new(xml)
    pubsub = iq.payload.as(XMPP::Stanza::PubSub)

    if items = pubsub.items
      puts "Node: #{items.node}"
      puts "Found #{items.items.size} items:"
      items.items.each do |item|
        puts "  - Item ID: #{item.id}"
      end
    end
  end

  # Example 9: Publish item with PEP payload (User Tune)
  def self.publish_tune
    puts "\n=== Publish User Tune ==="

    iq = XMPP::Stanza::IQ.new
    iq.type = "set"
    iq.from = "hamlet@denmark.lit/castle"
    iq.to = "pubsub.shakespeare.lit"
    iq.id = "pub1"

    pubsub = XMPP::Stanza::PubSub.new
    publish = XMPP::Stanza::Publish.new
    publish.node = "http://jabber.org/protocol/tune"

    item = XMPP::Stanza::Item.new
    item.id = "current"

    tune = XMPP::Stanza::Tune.new
    tune.artist = "The Beatles"
    tune.title = "Hey Jude"
    tune.length = 431
    item.tune = tune

    publish.item = item
    pubsub.publish = publish
    iq.payload = pubsub

    puts iq.to_xml
  end

  # Example 10: Retract item
  def self.retract_item
    puts "\n=== Retract Item ==="

    iq = XMPP::Stanza::IQ.new
    iq.type = "set"
    iq.from = "hamlet@denmark.lit/castle"
    iq.to = "pubsub.shakespeare.lit"
    iq.id = "retract1"

    pubsub = XMPP::Stanza::PubSub.new
    retract = XMPP::Stanza::Retract.new
    retract.node = "princely_musings"
    retract.notify = "true"

    item = XMPP::Stanza::Item.new
    item.id = "ae890ac52d0df67ed7cfdf51b644e901"

    retract.item = item
    pubsub.retract = retract
    iq.payload = pubsub

    puts iq.to_xml
  end

  # Run all examples
  def self.run_all
    puts "=" * 60
    puts "XEP-0060 PubSub Enhanced Examples"
    puts "=" * 60

    subscribe_to_node
    unsubscribe_from_node
    retrieve_subscriptions
    parse_subscription_response
    retrieve_affiliations
    parse_affiliation_response
    retrieve_items
    parse_items_response
    publish_tune
    retract_item

    puts "\n" + "=" * 60
    puts "All examples completed!"
    puts "=" * 60
  end
end

# Run examples
PubSubExample.run_all
