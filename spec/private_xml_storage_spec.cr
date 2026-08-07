require "./spec_helper"
require "../src/xmpp/stanza/iq/private_storage"

private class PrivateStorageStubClient < XMPP::Client
  getter requested : Array(XMPP::Stanza::IQ) = [] of XMPP::Stanza::IQ
  property response : XMPP::Stanza::IQ? = nil

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def request(iq : XMPP::Stanza::IQ, timeout : Time::Span = 5.seconds) : XMPP::Stanza::IQ?
    @requested << iq
    @response
  end

  def bare_jid : String
    "test@localhost"
  end
end

describe XMPP::Stanza::PrivateQuery do
  it "parses a query carrying stored data as a generic node" do
    query = XMPP::Stanza::PrivateQuery.new(<<-XML)
      <query xmlns='jabber:iq:private'>
        <storage xmlns='storage:bookmarks'>
          <bookmark name='Example'/>
        </storage>
      </query>
      XML

    data = query.data.should_not be_nil
    data.xml_name.space.should eq "storage:bookmarks"
    data.xml_name.local.should eq "storage"
    data.nodes.size.should eq 1
    data.nodes.first.name.should eq "bookmark"
    data.nodes.first.attrs["name"].should eq "Example"
  end

  it "serializes the query wrapper around the stored node" do
    query = XMPP::Stanza::PrivateQuery.new
    node = XMPP::Stanza::Node.new
    node.xml_name = XMPP::Stanza::XMLName.new("storage:bookmarks", "storage")
    node.contents = "notes"
    query.data = node

    xml = XML.build { |x| query.to_xml(x) }
    xml.should contain("xmlns=\"jabber:iq:private\"")
    xml.should contain("<storage xmlns=\"storage:bookmarks\">notes</storage>")
  end
end

describe XMPP::PrivateXmlStorage do
  it "retrieve sends an IQ-get carrying an empty placeholder and returns the stored node" do
    client = PrivateStorageStubClient.new
    data = XMPP::Stanza::Node.new
    data.xml_name = XMPP::Stanza::XMLName.new("storage:bookmarks", "storage")
    data.contents = "notes"
    result_query = XMPP::Stanza::PrivateQuery.new
    result_query.data = data
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    result.payload = result_query
    client.response = result

    node = XMPP::PrivateXmlStorage.new(client).retrieve("storage:bookmarks", "storage")

    node.should_not be_nil
    node.not_nil!.xml_name.space.should eq "storage:bookmarks"
    node.not_nil!.contents.should eq "notes"

    iq = client.requested.first
    iq.type.should eq "get"
    iq.to.should eq "test@localhost"
    query = iq.payload.as(XMPP::Stanza::PrivateQuery)
    placeholder = query.data.should_not be_nil
    placeholder.xml_name.space.should eq "storage:bookmarks"
    placeholder.xml_name.local.should eq "storage"
  end

  it "retrieve returns nil on an error result" do
    client = PrivateStorageStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "error"
    client.response = result

    XMPP::PrivateXmlStorage.new(client).retrieve("storage:bookmarks", "storage").should be_nil
  end

  it "store sends an IQ-set carrying the node" do
    client = PrivateStorageStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    node = XMPP::Stanza::Node.new
    node.xml_name = XMPP::Stanza::XMLName.new("storage:bookmarks", "storage")
    node.contents = "notes"
    response = XMPP::PrivateXmlStorage.new(client).store(node)

    response.should be result
    iq = client.requested.first
    iq.type.should eq "set"
    iq.to.should eq "test@localhost"
    query = iq.payload.as(XMPP::Stanza::PrivateQuery)
    query.data.should be node
  end

  it "store builds a node from namespace, name, and contents" do
    client = PrivateStorageStubClient.new
    result = XMPP::Stanza::IQ.new
    result.type = "result"
    client.response = result

    XMPP::PrivateXmlStorage.new(client).store("storage:bookmarks", "storage", "notes")

    iq = client.requested.first
    query = iq.payload.as(XMPP::Stanza::PrivateQuery)
    node = query.data.should_not be_nil
    node.xml_name.space.should eq "storage:bookmarks"
    node.xml_name.local.should eq "storage"
    node.contents.should eq "notes"
  end
end
