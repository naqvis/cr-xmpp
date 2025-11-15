require "./pep"
require "./registry"

module XMPP::Stanza
  # # PubSub Stanza
  #
  # [XEP-0060 - Publish-Subscribe](http://xmpp.org/extensions/xep-0060.html)
  #
  # Enhanced implementation with subscription management, item retrieval, and affiliations

  class PubSub < MsgExtension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/pubsub", "pubsub")
    property publish : Publish? = nil
    property retract : Retract? = nil
    property subscribe : Subscribe? = nil
    property unsubscribe : Unsubscribe? = nil
    property subscription : Subscription? = nil
    property subscriptions : Subscriptions? = nil
    property affiliations : Affiliations? = nil
    property items : Items? = nil

    def self.new(xml : String)
      doc = XML.parse(xml)
      root = doc.first_element_child
      if root
        new(root)
      else
        raise "Invalid XML"
      end
    end

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                        (node.name == @@xml_name.local)
      pr = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "publish"       then pr.publish = Publish.new(child)
        when "retract"       then pr.retract = Retract.new(child)
        when "subscribe"     then pr.subscribe = Subscribe.new(child)
        when "unsubscribe"   then pr.unsubscribe = Unsubscribe.new(child)
        when "subscription"  then pr.subscription = Subscription.new(child)
        when "subscriptions" then pr.subscriptions = Subscriptions.new(child)
        when "affiliations"  then pr.affiliations = Affiliations.new(child)
        when "items"         then pr.items = Items.new(child)
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        publish.try &.to_xml xml
        retract.try &.to_xml xml
        subscribe.try &.to_xml xml
        unsubscribe.try &.to_xml xml
        subscription.try &.to_xml xml
        subscriptions.try &.to_xml xml
        affiliations.try &.to_xml xml
        items.try &.to_xml xml
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  # Subscribe element for subscribing to a node
  class Subscribe
    class_getter xml_name : String = "subscribe"
    property node : String = ""
    property jid : String = ""

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node" then pr.node = attr.children[0].content
        when "jid"  then pr.jid = attr.children[0].content
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      dict["jid"] = jid unless jid.blank?
      xml.element(@@xml_name, dict)
    end
  end

  # Unsubscribe element for unsubscribing from a node
  class Unsubscribe
    class_getter xml_name : String = "unsubscribe"
    property node : String = ""
    property jid : String = ""
    property subid : String = ""

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node"  then pr.node = attr.children[0].content
        when "jid"   then pr.jid = attr.children[0].content
        when "subid" then pr.subid = attr.children[0].content
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      dict["jid"] = jid unless jid.blank?
      dict["subid"] = subid unless subid.blank?
      xml.element(@@xml_name, dict)
    end
  end

  # Subscription element representing subscription state
  class Subscription
    class_getter xml_name : String = "subscription"
    property node : String = ""
    property jid : String = ""
    property subid : String = ""
    property subscription : String = "" # none, pending, subscribed, unconfigured

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node"         then pr.node = attr.children[0].content
        when "jid"          then pr.jid = attr.children[0].content
        when "subid"        then pr.subid = attr.children[0].content
        when "subscription" then pr.subscription = attr.children[0].content
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      dict["jid"] = jid unless jid.blank?
      dict["subid"] = subid unless subid.blank?
      dict["subscription"] = subscription unless subscription.blank?
      xml.element(@@xml_name, dict)
    end
  end

  # Subscriptions element containing multiple subscriptions
  class Subscriptions
    class_getter xml_name : String = "subscriptions"
    property node : String = ""
    property subscriptions : Array(Subscription) = [] of Subscription

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node" then pr.node = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        if child.name == "subscription"
          pr.subscriptions << Subscription.new(child)
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      xml.element(@@xml_name, dict) do
        subscriptions.each &.to_xml(xml)
      end
    end
  end

  # Affiliation element representing affiliation with a node
  class Affiliation
    class_getter xml_name : String = "affiliation"
    property node : String = ""
    property jid : String = ""
    property affiliation : String = "" # owner, publisher, publish-only, member, outcast, none

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node"        then pr.node = attr.children[0].content
        when "jid"         then pr.jid = attr.children[0].content
        when "affiliation" then pr.affiliation = attr.children[0].content
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      dict["jid"] = jid unless jid.blank?
      dict["affiliation"] = affiliation unless affiliation.blank?
      xml.element(@@xml_name, dict)
    end
  end

  # Affiliations element containing multiple affiliations
  class Affiliations
    class_getter xml_name : String = "affiliations"
    property node : String = ""
    property affiliations : Array(Affiliation) = [] of Affiliation

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node" then pr.node = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        if child.name == "affiliation"
          pr.affiliations << Affiliation.new(child)
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      xml.element(@@xml_name, dict) do
        affiliations.each &.to_xml(xml)
      end
    end
  end

  # Items element for retrieving items from a node
  class Items
    class_getter xml_name : String = "items"
    property node : String = ""
    property max_items : String = ""
    property subid : String = ""
    property items : Array(Item) = [] of Item

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node"      then pr.node = attr.children[0].content
        when "max_items" then pr.max_items = attr.children[0].content
        when "subid"     then pr.subid = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        if child.name == "item"
          pr.items << Item.new(child)
        end
      end
      pr
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      dict["max_items"] = max_items unless max_items.blank?
      dict["subid"] = subid unless subid.blank?
      xml.element(@@xml_name, dict) do
        items.each &.to_xml(xml)
      end
    end
  end

  class Publish
    class_getter xml_name : String = "publish"
    property node : String = ""
    property item : Item? = nil

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name

      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node" then pr.node = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        pr.item = Item.new(child)
        break
      end
      pr
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?

      xml.element(@@xml_name, dict) do
        item.try &.to_xml xml
      end
    end
  end

  class Item
    class_getter xml_name : String = "item"
    property id : String = ""
    property tune : Tune? = nil
    property mood : Mood? = nil

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "id" then pr.id = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "tune" then pr.tune = Tune.new(child)
        when "mood" then pr.mood = Mood.new(child)
        end
      end
      pr
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["id"] = id unless id.blank?

      xml.element(@@xml_name, dict) do
        tune.try &.to_xml xml
        mood.try &.to_xml xml
      end
    end
  end

  class Retract
    class_getter xml_name : String = "retract"
    property node : String = ""
    property notify : String = ""
    property item : Item? = nil

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      node.attributes.each do |attr|
        case attr.name
        when "node"   then pr.node = attr.children[0].content
        when "notify" then pr.notify = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        pr.item = Item.new(child)
        break
      end
      pr
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["node"] = node unless node.blank?
      dict["notify"] = notify unless notify.blank?

      xml.element(@@xml_name, dict) do
        item.try &.to_xml xml
      end
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new("http://jabber.org/protocol/pubsub", "pubsub"), PubSub)
end
