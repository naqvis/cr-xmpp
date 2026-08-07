require "./spec_helper"
require "../src/xmpp/stanza/avatar"
require "../src/xmpp/stanza/iq/vcard"
require "../src/xmpp/stanza"

private class AvatarStubClient < XMPP::Client
  getter sent : Array(XMPP::Stanza::IQ) = [] of XMPP::Stanza::IQ

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def send(stanza : XMPP::Stanza::IQ)
    @sent << stanza
  end

  def bare_jid : String
    "test@localhost"
  end
end

describe XMPP::Stanza::AvatarData do
  it "parses base64 avatar data" do
    data = XMPP::Stanza::AvatarData.new(
      "<data xmlns='urn:xmpp:avatar:data'>YWJjZA==</data>"
    )
    data.data.should eq "YWJjZA=="
  end

  it "serializes avatar data" do
    data = XMPP::Stanza::AvatarData.new
    data.data = "YWJjZA=="

    xml = XML.build { |x| data.to_xml(x) }
    xml.should contain("urn:xmpp:avatar:data")
    xml.should contain("YWJjZA==")
  end
end

describe XMPP::Stanza::AvatarMetadata do
  it "parses metadata with format info" do
    metadata = XMPP::Stanza::AvatarMetadata.new(<<-XML)
      <metadata xmlns='urn:xmpp:avatar:metadata'>
        <info id='111f4b3c50d7b0df729d299bc6f8e9ef9066971f' type='image/png' bytes='2048' width='64' height='64'/>
      </metadata>
      XML

    info = metadata.infos.first
    info.id.should eq "111f4b3c50d7b0df729d299bc6f8e9ef9066971f"
    info.type.should eq "image/png"
    info.bytes.should eq 2048
    info.width.should eq 64
    info.height.should eq 64
  end

  it "serializes metadata" do
    metadata = XMPP::Stanza::AvatarMetadata.new
    info = XMPP::Stanza::AvatarInfo.new
    info.id = "abc"
    info.type = "image/png"
    info.bytes = 2048
    metadata.infos << info

    xml = XML.build { |x| metadata.to_xml(x) }
    xml.should contain("urn:xmpp:avatar:metadata")
    xml.should contain("type=\"image/png\"")
    xml.should contain("bytes=\"2048\"")
  end

  it "round-trips through the generic node model" do
    metadata = XMPP::Stanza::AvatarMetadata.new
    info = XMPP::Stanza::AvatarInfo.new
    info.id = "abc"
    info.type = "image/png"
    metadata.infos << info

    restored = XMPP::Stanza::AvatarMetadata.from_node(metadata.to_node)
    restored.should_not be_nil
    restored.not_nil!.infos.first.id.should eq "abc"
  end
end

describe XMPP::UserAvatar do
  it "publish sends data and metadata items to the avatar nodes" do
    client = AvatarStubClient.new

    XMPP::UserAvatar.new(client).publish("YWJjZA==", "image/png", 4, id: "abc", width: 64, height: 64)

    client.sent.size.should eq 2
    data_iq = client.sent[0]
    data_publish = data_iq.payload.as(XMPP::Stanza::PubSub).publish.not_nil!
    data_publish.node.should eq "urn:xmpp:avatar:data"
    data_publish.item.not_nil!.id.should eq "abc"
    data_payload = XMPP::Stanza::AvatarData.from_node(data_publish.item.not_nil!.extra.not_nil!)
    data_payload.not_nil!.data.should eq "YWJjZA=="

    meta_iq = client.sent[1]
    meta_publish = meta_iq.payload.as(XMPP::Stanza::PubSub).publish.not_nil!
    meta_publish.node.should eq "urn:xmpp:avatar:metadata"
    meta_payload = XMPP::Stanza::AvatarMetadata.from_node(meta_publish.item.not_nil!.extra.not_nil!)
    info = meta_payload.not_nil!.infos.first
    info.id.should eq "abc"
    info.type.should eq "image/png"
    info.bytes.should eq 4
    info.width.should eq 64
    info.height.should eq 64
  end

  it "metadata_from_message extracts metadata from a notification" do
    message = XMPP::Stanza::Message.new(<<-XML)
      <message from='juliet@capulet.lit' to='romeo@montague.lit'>
        <event xmlns='http://jabber.org/protocol/pubsub#event'>
          <items node='urn:xmpp:avatar:metadata'>
            <item id='abc'>
              <metadata xmlns='urn:xmpp:avatar:metadata'>
                <info id='abc' type='image/png' bytes='4'/>
              </metadata>
            </item>
          </items>
        </event>
      </message>
      XML

    metadata = XMPP::UserAvatar.metadata_from_message(message)

    metadata.should_not be_nil
    metadata.not_nil!.infos.first.type.should eq "image/png"
  end

  it "converts avatar data to a vCard photo and back (XEP-0398)" do
    photo = XMPP::UserAvatar.to_vcard_photo("YWJjZA==", "image/png")
    photo.type.should eq "image/png"
    photo.binval.should eq "YWJjZA=="

    data = XMPP::UserAvatar.avatar_from_photo(photo)
    data.data.should eq "YWJjZA=="
  end
end
