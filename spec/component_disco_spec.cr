require "./spec_helper"

describe "XEP-0030: Service Discovery for Components" do
  describe XMPP::ComponentDisco::DiscoIdentity do
    it "creates identity with all fields" do
      identity = XMPP::ComponentDisco::DiscoIdentity.new(
        category: "gateway",
        type: "sms",
        name: "SMS Gateway",
        xml_lang: "en"
      )

      identity.category.should eq "gateway"
      identity.type.should eq "sms"
      identity.name.should eq "SMS Gateway"
      identity.xml_lang.should eq "en"
    end

    it "converts to Stanza::Identity" do
      identity = XMPP::ComponentDisco::DiscoIdentity.new(
        category: "conference",
        type: "text",
        name: "Chatrooms"
      )

      stanza_identity = identity.to_identity
      stanza_identity.category.should eq "conference"
      stanza_identity.type.should eq "text"
      stanza_identity.name.should eq "Chatrooms"
    end
  end

  describe XMPP::ComponentDisco::DiscoInfo do
    it "initializes with default disco features" do
      info = XMPP::ComponentDisco::DiscoInfo.new

      info.features.should contain("http://jabber.org/protocol/disco#info")
      info.features.should contain("http://jabber.org/protocol/disco#items")
    end

    it "adds identities" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      info.add_identity("gateway", "sms", "SMS Gateway")

      info.identities.size.should eq 1
      info.identities[0].category.should eq "gateway"
      info.identities[0].type.should eq "sms"
      info.identities[0].name.should eq "SMS Gateway"
    end

    it "adds multiple identities" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      info.add_identity("conference", "text", "Chatrooms")
      info.add_identity("directory", "chatroom", "Room Directory")

      info.identities.size.should eq 2
    end

    it "adds features" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      info.add_feature("http://jabber.org/protocol/muc")

      info.features.should contain("http://jabber.org/protocol/muc")
    end

    it "prevents duplicate features" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      info.add_feature("http://jabber.org/protocol/muc")
      info.add_feature("http://jabber.org/protocol/muc")

      info.features.count("http://jabber.org/protocol/muc").should eq 1
    end

    it "adds multiple features at once" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      info.add_features([
        "http://jabber.org/protocol/muc",
        "jabber:iq:register",
        "jabber:iq:search",
      ])

      info.features.should contain("http://jabber.org/protocol/muc")
      info.features.should contain("jabber:iq:register")
      info.features.should contain("jabber:iq:search")
    end

    it "builds response for root node" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      info.add_identity("gateway", "sms", "SMS Gateway")
      info.add_feature("jabber:iq:gateway")

      response = info.build_response

      response.node.should be_empty
      response.identity.size.should eq 1
      response.identity[0].category.should eq "gateway"
      response.features.size.should be >= 3 # disco#info, disco#items, + jabber:iq:gateway
    end

    it "supports nodes" do
      info = XMPP::ComponentDisco::DiscoInfo.new

      node_info = XMPP::ComponentDisco::DiscoNodeInfo.new
      node_info.add_identity("automation", "command-list")
      node_info.add_feature("http://jabber.org/protocol/commands")

      info.add_node("http://jabber.org/protocol/commands", node_info)

      response = info.build_response("http://jabber.org/protocol/commands")
      response.node.should eq "http://jabber.org/protocol/commands"
      response.identity.size.should eq 1
      response.identity[0].category.should eq "automation"
    end

    it "returns empty response for unknown node" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      info.add_identity("gateway", "sms")

      response = info.build_response("unknown-node")
      response.node.should eq "unknown-node"
      response.identity.should be_empty
      response.features.should be_empty
    end
  end

  describe XMPP::ComponentDisco::DiscoNodeInfo do
    it "initializes with disco feature" do
      node_info = XMPP::ComponentDisco::DiscoNodeInfo.new

      node_info.features.should contain("http://jabber.org/protocol/disco#info")
    end

    it "adds identity and features" do
      node_info = XMPP::ComponentDisco::DiscoNodeInfo.new
      node_info.add_identity("automation", "command-list", "Available Commands")
      node_info.add_feature("http://jabber.org/protocol/commands")

      node_info.identities.size.should eq 1
      node_info.identities[0].category.should eq "automation"
      node_info.features.should contain("http://jabber.org/protocol/commands")
    end
  end

  describe XMPP::ComponentDisco::DiscoItems do
    it "adds items to root" do
      items = XMPP::ComponentDisco::DiscoItems.new
      items.add_item("room1@conference.example.com", "", "Room 1")
      items.add_item("room2@conference.example.com", "", "Room 2")

      items.items.size.should eq 2
      items.items[0].jid.should eq "room1@conference.example.com"
      items.items[1].name.should eq "Room 2"
    end

    it "adds items with nodes" do
      items = XMPP::ComponentDisco::DiscoItems.new
      items.add_item("pubsub.example.com", "node1", "Node 1")

      items.items.size.should eq 1
      items.items[0].node.should eq "node1"
    end

    it "adds items to specific nodes" do
      items = XMPP::ComponentDisco::DiscoItems.new
      items.add_node_item("music", "pubsub.example.com", "music/rock", "Rock Music")
      items.add_node_item("music", "pubsub.example.com", "music/jazz", "Jazz Music")

      items.node_items["music"].size.should eq 2
      items.node_items["music"][0].node.should eq "music/rock"
    end

    it "builds response for root" do
      items = XMPP::ComponentDisco::DiscoItems.new
      items.add_item("room1@conference.example.com", "", "Room 1")
      items.add_item("room2@conference.example.com", "", "Room 2")

      response = items.build_response

      response.node.should be_empty
      response.items.size.should eq 2
    end

    it "builds response for specific node" do
      items = XMPP::ComponentDisco::DiscoItems.new
      items.add_node_item("music", "pubsub.example.com", "music/rock", "Rock")
      items.add_node_item("books", "pubsub.example.com", "books/fiction", "Fiction")

      response = items.build_response("music")
      response.node.should eq "music"
      response.items.size.should eq 1
      response.items[0].node.should eq "music/rock"
    end

    it "returns empty response for unknown node" do
      items = XMPP::ComponentDisco::DiscoItems.new
      items.add_item("room1@conference.example.com")

      response = items.build_response("unknown-node")
      response.node.should eq "unknown-node"
      response.items.should be_empty
    end
  end

  describe "Integration" do
    it "builds complete disco#info response" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      info.add_identity("conference", "text", "Chatrooms")
      info.add_identity("directory", "chatroom", "Room Directory")
      info.add_features([
        "http://jabber.org/protocol/muc",
        "jabber:iq:register",
        "jabber:iq:search",
      ])

      response = info.build_response
      xml = response.to_xml

      xml.should contain("category=\"conference\"")
      xml.should contain("type=\"text\"")
      xml.should contain("var=\"http://jabber.org/protocol/muc\"")
      xml.should contain("var=\"http://jabber.org/protocol/disco#info\"")
    end

    it "builds complete disco#items response" do
      items = XMPP::ComponentDisco::DiscoItems.new
      items.add_item("room1@conference.example.com", "", "General Discussion")
      items.add_item("room2@conference.example.com", "", "Tech Talk")

      response = items.build_response
      xml = response.to_xml

      xml.should contain("jid=\"room1@conference.example.com\"")
      xml.should contain("name=\"General Discussion\"")
      xml.should contain("jid=\"room2@conference.example.com\"")
    end

    it "supports hierarchical nodes" do
      info = XMPP::ComponentDisco::DiscoInfo.new
      items = XMPP::ComponentDisco::DiscoItems.new

      # Add root items
      items.add_item("catalog.example.com", "books", "Books")
      items.add_item("catalog.example.com", "music", "Music")

      # Add node info for books
      books_info = XMPP::ComponentDisco::DiscoNodeInfo.new
      books_info.add_identity("hierarchy", "branch", "Book Categories")
      info.add_node("books", books_info)

      # Add items under books node
      items.add_node_item("books", "catalog.example.com", "books/fiction", "Fiction")
      items.add_node_item("books", "catalog.example.com", "books/nonfiction", "Non-Fiction")

      # Test root items
      root_response = items.build_response
      root_response.items.size.should eq 2

      # Test books node items
      books_response = items.build_response("books")
      books_response.items.size.should eq 2
      books_response.items[0].node.should eq "books/fiction"

      # Test books node info
      books_info_response = info.build_response("books")
      books_info_response.identity[0].category.should eq "hierarchy"
      books_info_response.identity[0].type.should eq "branch"
    end
  end
end
