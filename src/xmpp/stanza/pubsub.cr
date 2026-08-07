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
    property publish_options : PublishOptions? = nil

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
        when "publish"         then pr.publish = Publish.new(child)
        when "retract"         then pr.retract = Retract.new(child)
        when "subscribe"       then pr.subscribe = Subscribe.new(child)
        when "unsubscribe"     then pr.unsubscribe = Unsubscribe.new(child)
        when "subscription"    then pr.subscription = Subscription.new(child)
        when "subscriptions"   then pr.subscriptions = Subscriptions.new(child)
        when "affiliations"    then pr.affiliations = Affiliations.new(child)
        when "items"           then pr.items = Items.new(child)
        when "publish-options" then pr.publish_options = PublishOptions.new(child)
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
        publish_options.try &.to_xml xml
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
    property raw_node : XML::Node? = nil
    # extra holds a generic serializable payload for PEP item types that have
    # no dedicated field (bookmarks, avatars, ...). It round-trips through the
    # generic Node model.
    property extra : Node? = nil

    def self.new(node : XML::Node)
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      pr.raw_node = node
      node.attributes.each do |attr|
        case attr.name
        when "id" then pr.id = attr.children[0].content
        end
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "tune" then pr.tune = Tune.new(child)
        when "mood" then pr.mood = Mood.new(child)
        else
          pr.extra = Node.new(child) unless pr.extra
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
        extra.try &.to_xml xml
      end
    end
  end

  # XData models a jabber:x:data form (XEP-0004) carried inside pubsub
  # publish-options. It is intentionally minimal: a form type plus a flat list
  # of fields, each with a var, an optional value and label.
  class XData
    class_getter xml_name : String = "x"
    property type : String = ""
    getter fields : Array(XDataField) = [] of XDataField

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      cls.type = node["type"]? || ""
      node.children.select(&.element?).each do |child|
        cls.fields << XDataField.new(child) if child.name == "field"
      end
      cls
    end

    # field returns the value of the field with the given var, or nil.
    def field(var : String) : String?
      fields.find { |f| f.var == var }.try &.value
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = "jabber:x:data"
      dict["type"] = type unless type.blank?
      xml.element(@@xml_name, dict) do
        fields.each &.to_xml(xml)
      end
    end
  end

  # XDataField is a single field of an XData form.
  class XDataField
    class_getter xml_name : String = "field"
    property var : String = ""
    property type : String = ""
    property label : String = ""
    property value : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      cls.var = node["var"]? || ""
      cls.type = node["type"]? || ""
      cls.label = node["label"]? || ""
      cls.value = node.children.select(&.element?).find { |c| c.name == "value" }.try(&.content) || ""
      cls
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["var"] = var unless var.blank?
      dict["type"] = type unless type.blank?
      dict["label"] = label unless label.blank?
      xml.element(@@xml_name, dict) do
        unless value.blank?
          xml.element("value") { xml.text value }
        end
      end
    end
  end

  # PublishOptions implements the publish-options element of XEP-0410 - PubSub
  # Publish Options. It is sent alongside a publish to configure the node via a
  # jabber:x:data form (typically the pubsub#access_model field).
  class PublishOptions
    class_getter xml_name : XMLName = XMLName.new("http://jabber.org/protocol/pubsub#publish-options", "publish-options")
    property form : XData? = nil

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
      cls = new()
      node.children.select(&.element?).each do |child|
        cls.form = XData.new(child) if child.name == "x"
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        form.try &.to_xml xml
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
