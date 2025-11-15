require "./spec_helper"

describe "XEP-0355: Namespace Delegation" do
  describe XMPP::Stanza::Delegation do
    it "parses delegation with forwarded stanza" do
      xml = <<-XML
        <delegation xmlns='urn:xmpp:delegation:2'>
          <forwarded xmlns='urn:xmpp:forward:0'>
            <iq type='get' id='test1' xmlns='jabber:client'>
              <query xmlns='http://jabber.org/protocol/disco#info'/>
            </iq>
          </forwarded>
        </delegation>
      XML

      delegation = XMPP::Stanza::Delegation.new(XML.parse(xml).first_element_child.not_nil!)

      delegation.forwarded.should_not be_nil
      delegation.delegated.should be_empty
    end

    it "parses delegation advertisement with delegated namespaces" do
      xml = <<-XML
        <delegation xmlns='urn:xmpp:delegation:2'>
          <delegated namespace='http://jabber.org/protocol/pubsub'/>
          <delegated namespace='urn:xmpp:mam:2'>
            <attribute name='node'/>
          </delegated>
        </delegation>
      XML

      delegation = XMPP::Stanza::Delegation.new(XML.parse(xml).first_element_child.not_nil!)

      delegation.delegated.size.should eq 2
      delegation.delegated[0].namespace.should eq "http://jabber.org/protocol/pubsub"
      delegation.delegated[0].attributes.should be_empty

      delegation.delegated[1].namespace.should eq "urn:xmpp:mam:2"
      delegation.delegated[1].attributes.size.should eq 1
      delegation.delegated[1].attributes[0].name.should eq "node"
    end

    it "serializes delegation with forwarded" do
      delegation = XMPP::Stanza::Delegation.new

      # Create a simple forwarded IQ
      iq = XMPP::Stanza::IQ.new
      iq.type = "result"
      iq.id = "test1"

      forwarded = XMPP::Stanza::Forwarded.new
      forwarded.stanza = iq

      delegation.forwarded = forwarded

      xml = delegation.to_xml

      xml.should contain("<delegation")
      xml.should contain("xmlns=\"urn:xmpp:delegation:2\"")
      xml.should contain("<forwarded")
    end

    it "serializes delegation advertisement" do
      delegation = XMPP::Stanza::Delegation.new

      delegated1 = XMPP::Stanza::Delegated.new
      delegated1.namespace = "http://jabber.org/protocol/pubsub"

      delegated2 = XMPP::Stanza::Delegated.new
      delegated2.namespace = "urn:xmpp:mam:2"

      attr = XMPP::Stanza::DelegatedAttribute.new
      attr.name = "node"
      delegated2.attributes << attr

      delegation.delegated << delegated1
      delegation.delegated << delegated2

      xml = delegation.to_xml

      xml.should contain("namespace=\"http://jabber.org/protocol/pubsub\"")
      xml.should contain("namespace=\"urn:xmpp:mam:2\"")
      xml.should contain("<attribute")
      xml.should contain("name=\"node\"")
    end
  end

  describe XMPP::ComponentDelegation::DelegationManager do
    it "adds and tracks delegations" do
      manager = XMPP::ComponentDelegation::DelegationManager.new

      manager.add_delegation("http://jabber.org/protocol/pubsub")
      manager.add_delegation("urn:xmpp:mam:2", ["node"])

      manager.delegated?("http://jabber.org/protocol/pubsub").should be_true
      manager.delegated?("urn:xmpp:mam:2").should be_true
      manager.delegated?("unknown:namespace").should be_false
    end

    it "retrieves delegation info" do
      manager = XMPP::ComponentDelegation::DelegationManager.new

      manager.add_delegation("urn:xmpp:mam:2", ["node"])

      info = manager.get_delegation("urn:xmpp:mam:2")
      info.should_not be_nil
      info.not_nil!.namespace.should eq "urn:xmpp:mam:2"
      info.not_nil!.attributes.should eq ["node"]
    end
  end
end

describe "XEP-0356: Privileged Entity" do
  describe XMPP::Stanza::Privilege do
    it "parses privilege advertisement" do
      xml = <<-XML
        <privilege xmlns='urn:xmpp:privilege:2'>
          <perm access='roster' type='both' push='true'/>
          <perm access='message' type='outgoing'/>
        </privilege>
      XML

      privilege = XMPP::Stanza::Privilege.new(XML.parse(xml).first_element_child.not_nil!)

      privilege.perms.size.should eq 2
      privilege.perms[0].access.should eq "roster"
      privilege.perms[0].type.should eq "both"
      privilege.perms[0].push.should eq "true"

      privilege.perms[1].access.should eq "message"
      privilege.perms[1].type.should eq "outgoing"
    end

    it "parses privilege with IQ namespaces" do
      xml = <<-XML
        <privilege xmlns='urn:xmpp:privilege:2'>
          <perm access='iq' type='set'>
            <namespace>jabber:iq:roster</namespace>
            <namespace>http://jabber.org/protocol/pubsub</namespace>
          </perm>
        </privilege>
      XML

      privilege = XMPP::Stanza::Privilege.new(XML.parse(xml).first_element_child.not_nil!)

      privilege.perms.size.should eq 1
      privilege.perms[0].access.should eq "iq"
      privilege.perms[0].type.should eq "set"
      privilege.perms[0].namespaces.size.should eq 2
      privilege.perms[0].namespaces[0].value.should eq "jabber:iq:roster"
      privilege.perms[0].namespaces[1].value.should eq "http://jabber.org/protocol/pubsub"
    end

    it "serializes privilege advertisement" do
      privilege = XMPP::Stanza::Privilege.new

      perm1 = XMPP::Stanza::Perm.new
      perm1.access = "roster"
      perm1.type = "both"
      perm1.push = "true"

      perm2 = XMPP::Stanza::Perm.new
      perm2.access = "message"
      perm2.type = "outgoing"

      privilege.perms << perm1
      privilege.perms << perm2

      xml = privilege.to_xml

      xml.should contain("<privilege")
      xml.should contain("xmlns=\"urn:xmpp:privilege:2\"")
      xml.should contain("access=\"roster\"")
      xml.should contain("type=\"both\"")
      xml.should contain("push=\"true\"")
      xml.should contain("access=\"message\"")
      xml.should contain("type=\"outgoing\"")
    end
  end

  describe XMPP::ComponentPrivilege::PrivilegeManager do
    it "adds and tracks permissions" do
      manager = XMPP::ComponentPrivilege::PrivilegeManager.new

      manager.add_permission("roster", XMPP::ComponentPrivilege::PermissionType::Both, push: true)
      manager.add_permission("message", XMPP::ComponentPrivilege::PermissionType::Outgoing)

      manager.has_permission?("roster").should be_true
      manager.has_permission?("message").should be_true
      manager.has_permission?("iq").should be_false
    end

    it "checks roster permissions" do
      manager = XMPP::ComponentPrivilege::PrivilegeManager.new

      manager.add_permission("roster", XMPP::ComponentPrivilege::PermissionType::Both, push: true)

      manager.can_get_roster?.should be_true
      manager.can_set_roster?.should be_true
      manager.receives_roster_pushes?.should be_true
    end

    it "checks message permissions" do
      manager = XMPP::ComponentPrivilege::PrivilegeManager.new

      manager.add_permission("message", XMPP::ComponentPrivilege::PermissionType::Outgoing)

      manager.can_send_messages?.should be_true
    end

    it "checks IQ permissions with namespaces" do
      manager = XMPP::ComponentPrivilege::PrivilegeManager.new

      manager.add_permission("iq", XMPP::ComponentPrivilege::PermissionType::Set,
        namespaces: ["jabber:iq:roster", "http://jabber.org/protocol/pubsub"])

      manager.can_send_iq?("jabber:iq:roster").should be_true
      manager.can_send_iq?("http://jabber.org/protocol/pubsub").should be_true
      manager.can_send_iq?("unknown:namespace").should be_false
    end

    it "handles get-only roster permission" do
      manager = XMPP::ComponentPrivilege::PrivilegeManager.new

      manager.add_permission("roster", XMPP::ComponentPrivilege::PermissionType::Get)

      manager.can_get_roster?.should be_true
      manager.can_set_roster?.should be_false
      manager.receives_roster_pushes?.should be_false
    end

    it "handles set-only roster permission" do
      manager = XMPP::ComponentPrivilege::PrivilegeManager.new

      manager.add_permission("roster", XMPP::ComponentPrivilege::PermissionType::Set)

      manager.can_get_roster?.should be_false
      manager.can_set_roster?.should be_true
      manager.receives_roster_pushes?.should be_false
    end
  end
end
