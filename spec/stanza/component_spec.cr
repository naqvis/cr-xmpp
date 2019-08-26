require "../spec_helper"

module XMPP::Stanza
  it "We should be able to properly parse delegation confirmation messages" do
    xml = <<-XML
    <message to='service.localhost' from='localhost'>
        <delegation xmlns='urn:xmpp:delegation:1'>
            <delegated namespace='http://jabber.org/protocol/pubsub'/>
        </delegation>
    </message>
XML

    msg = Message.new xml
    # Check that we have extracted the delegation info as MsgExtension
    ns_delegated = ""
    msg.extensions.each do |ext|
      if ext.is_a?(Delegation)
        ns_delegated = ext.as(Delegation).delegated.try &.namespace
      end
    end
    ns_delegated.should eq("http://jabber.org/protocol/pubsub")
  end

  it "We should be able to properly parse delegation confirmation messages, and see if we can get" do
    xml = <<-XML
    <message to='service.localhost' from='localhost'>
        <delegation xmlns='urn:xmpp:delegation:1'>
            <delegated namespace='http://jabber.org/protocol/pubsub'/>
        </delegation>
    </message>
XML

    msg = Message.new xml
    # Check that we have extracted the delegation info as MsgExtension
    ns_delegated = msg.get(Delegation).try &.as(Delegation).delegated.try &.namespace
    ns_delegated.should eq("http://jabber.org/protocol/pubsub")
  end

  it "Check that we can parse a delegation IQ" do
    xml = <<-XML
    <iq to='service.localhost' from='localhost' type='set' id='1'>
 <delegation xmlns='urn:xmpp:delegation:1'>
  <forwarded xmlns='urn:xmpp:forward:0'>
   <iq xml:lang='en' to='test1@localhost' from='test1@localhost/mremond-mbp' type='set' id='aaf3a' xmlns='jabber:client'>
    <pubsub xmlns='http://jabber.org/protocol/pubsub'>
     <publish node='http://jabber.org/protocol/mood'>
      <item id='current'>
       <mood xmlns='http://jabber.org/protocol/mood'>
        <excited/>
       </mood>
      </item>
     </publish>
    </pubsub>
   </iq>
  </forwarded>
 </delegation>
</iq>
XML

    iq = IQ.new xml
    # Check that we have extracted the delegation info as IQPayload
    node = ""
    if (payload = iq.payload)
      delegation = payload.as(Delegation)
      packet = delegation.forwarded.try &.stanza
      fail "Could not extract packet IQ" if packet.nil? || !packet.is_a?(IQ)
      forwarded_iq = packet.try &.as(IQ)
      pubsub = forwarded_iq.payload.as(PubSub)
      node = pubsub.publish.try &.node
    end

    node.should eq("http://jabber.org/protocol/mood")
  end
end
