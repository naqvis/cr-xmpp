require "../../spec_helper"

module XMPP::Stanza
  it "Test Muc Password - https://xmpp.org/extensions/xep-0045.html#example-27" do
    xml = <<-XML
    <presence
    from='hag66@shakespeare.lit/pda'
    id='djn4714'
    to='coven@chat.shakespeare.lit/thirdwitch'>
    <x xmlns='http://jabber.org/protocol/muc'>
        <password>cauldronburn</password>
    </x>
    </presence>
XML
    presence = Presence.new xml

    if (muc = presence.get(MucPresence))
      muc = muc.as(MucPresence)
      muc.password.should eq("cauldronburn")
    else
      fail "muc presence extension was not found"
    end
  end

  it "User Requests Limit on Number of Messages in History" do
    # https://xmpp.org/extensions/xep-0045.html#example-37
    xml = <<-X
    <presence
    from='hag66@shakespeare.lit/pda'
    id='n13mt3l'
    to='coven@chat.shakespeare.lit/thirdwitch'>
  <x xmlns='http://jabber.org/protocol/muc'>
    <history maxstanzas='20'/>
  </x>
</presence>
X
    presence = Presence.new xml
    if (muc = presence.get(MucPresence))
      muc = muc.as(MucPresence)
      muc.history.try &.max_stanzas.should eq(20)
    else
      fail "muc presence extension was not found"
    end
  end

  it "User Requests History in Last 3 Minutes" do
    # https://xmpp.org/extensions/xep-0045.html#example-38
    xml = <<-X
    <presence
    from='hag66@shakespeare.lit/pda'
    id='n13mt3l'
    to='coven@chat.shakespeare.lit/thirdwitch'>
  <x xmlns='http://jabber.org/protocol/muc'>
    <history seconds='180'/>
  </x>
</presence>
X
    presence = Presence.new xml
    if (muc = presence.get(MucPresence))
      muc = muc.as(MucPresence)
      muc.history.try &.seconds.should eq(180)
    else
      fail "muc presence extension was not found"
    end
  end

  it "User Requests All History Since the Beginning of the Unix Era" do
    # https://xmpp.org/extensions/xep-0045.html#example-39
    xml = <<-X
    <presence
    from='hag66@shakespeare.lit/pda'
    id='n13mt3l'
    to='coven@chat.shakespeare.lit/thirdwitch'>
  <x xmlns='http://jabber.org/protocol/muc'>
    <history since='1970-01-01T00:00:00Z'/>
  </x>
</presence>
X
    presence = Presence.new xml
    if (muc = presence.get(MucPresence))
      muc = muc.as(MucPresence)
      muc.history.try &.since.should eq(DATE_TIME_FORMAT.parse("1970-01-01T00:00:00Z"))
    else
      fail "muc presence extension was not found"
    end
  end

  it " User Requests No History" do
    # https://xmpp.org/extensions/xep-0045.html#example-38
    xml = <<-X
    <presence
    from='hag66@shakespeare.lit/pda'
    id='n13mt3l'
    to='coven@chat.shakespeare.lit/thirdwitch'>
  <x xmlns='http://jabber.org/protocol/muc'>
    <history maxchars='0'/>
  </x>
</presence>
X
    presence = Presence.new xml
    if (muc = presence.get(MucPresence))
      muc = muc.as(MucPresence)
      muc.history.try &.max_chars.should eq(0)
    else
      fail "muc presence extension was not found"
    end
  end
end
