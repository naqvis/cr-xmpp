require "./spec_helper"
require "../src/xmpp/stanza/pubsub"
require "../src/xmpp/stanza"

private class PublishOptionsStubClient < XMPP::Client
  getter sent : Array(XMPP::Stanza::IQ) = [] of XMPP::Stanza::IQ

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def send(stanza : XMPP::Stanza::IQ)
    @sent << stanza
  end
end

describe XMPP::Stanza::PublishOptions do
  it "parses a publish-options form" do
    options = XMPP::Stanza::PublishOptions.new(<<-XML)
      <publish-options xmlns='http://jabber.org/protocol/pubsub#publish-options'>
        <x xmlns='jabber:x:data' type='submit'>
          <field var='FORM_TYPE' type='hidden'>
            <value>http://jabber.org/protocol/pubsub#publish-options</value>
          </field>
          <field var='pubsub#access_model'>
            <value>presence</value>
          </field>
        </x>
      </publish-options>
      XML

    form = options.form.not_nil!
    form.field("FORM_TYPE").should eq "http://jabber.org/protocol/pubsub#publish-options"
    form.field("pubsub#access_model").should eq "presence"
  end

  it "parses a pubsub element carrying publish-options" do
    pubsub = XMPP::Stanza::PubSub.new(<<-XML)
      <pubsub xmlns='http://jabber.org/protocol/pubsub'>
        <publish node='http://jabber.org/protocol/tune'>
          <item id='a'>
            <tune xmlns='http://jabber.org/protocol/tune'>
              <title>Raining on Sunday</title>
            </tune>
          </item>
        </publish>
        <publish-options xmlns='http://jabber.org/protocol/pubsub#publish-options'>
          <x xmlns='jabber:x:data' type='submit'>
            <field var='FORM_TYPE' type='hidden'>
              <value>http://jabber.org/protocol/pubsub#publish-options</value>
            </field>
            <field var='pubsub#access_model'>
              <value>presence</value>
            </field>
          </x>
        </publish-options>
      </pubsub>
      XML

    pubsub.publish.not_nil!.node.should eq "http://jabber.org/protocol/tune"
    options = pubsub.publish_options.not_nil!
    options.form.not_nil!.field("pubsub#access_model").should eq "presence"
  end

  it "serializes a publish with options" do
    options = XMPP::Stanza::PublishOptions.new
    form = XMPP::Stanza::XData.new
    form.type = "submit"
    form.fields << XMPP::Stanza::XDataField.new.tap do |f|
      f.var = "FORM_TYPE"
      f.type = "hidden"
      f.value = "http://jabber.org/protocol/pubsub#publish-options"
    end
    form.fields << XMPP::Stanza::XDataField.new.tap do |f|
      f.var = "pubsub#access_model"
      f.value = "presence"
    end
    options.form = form

    xml = XML.build { |x| options.to_xml(x) }
    xml.should contain "http://jabber.org/protocol/pubsub#publish-options"
    xml.should contain "<field var=\"pubsub#access_model\">"
    xml.should contain "<value>presence</value>"
  end
end

describe XMPP::PEP do
  it "publishes with publish-options (XEP-0410)" do
    client = PublishOptionsStubClient.new
    pep = XMPP::PEP.new(client)

    item = XMPP::Stanza::Item.new
    tune = XMPP::Stanza::Tune.new
    tune.title = "Raining on Sunday"
    item.tune = tune

    options = XMPP::Stanza::PublishOptions.new
    form = XMPP::Stanza::XData.new
    form.type = "submit"
    form.fields << XMPP::Stanza::XDataField.new.tap do |f|
      f.var = "FORM_TYPE"
      f.type = "hidden"
      f.value = "http://jabber.org/protocol/pubsub#publish-options"
    end
    form.fields << XMPP::Stanza::XDataField.new.tap do |f|
      f.var = "pubsub#access_model"
      f.value = "presence"
    end
    options.form = form

    pep.publish_with_options("http://jabber.org/protocol/tune", item, options)
    iq = client.sent.last
    iq.type.should eq "set"
    pubsub = iq.payload.as(XMPP::Stanza::PubSub)
    pubsub.publish.not_nil!.item.not_nil!.tune.not_nil!.title.should eq "Raining on Sunday"
    pubsub.publish_options.not_nil!.form.not_nil!.field("pubsub#access_model").should eq "presence"
  end
end
