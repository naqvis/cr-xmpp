require "./spec_helper"
require "../src/xmpp/stanza/jingle"
require "../src/xmpp/stanza"
require "../src/xmpp/jingle"

private class JingleStubClient < XMPP::Client
  getter sent : Array(XMPP::Stanza::IQ) = [] of XMPP::Stanza::IQ

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def send(stanza : XMPP::Stanza::IQ)
    @sent << stanza
  end
end

describe XMPP::Stanza do
  describe XMPP::Stanza::Jingle do
    it "parses a session-initiate with a file-transfer content" do
      jingle = XMPP::Stanza::Jingle.new(<<-XML)
        <jingle xmlns='urn:xmpp:jingle:1'
                action='session-initiate'
                initiator='juliet@capulet.lit/balcony'
                sid='a73sjjvkla37jfea'>
          <content creator='initiator' name='a-file-offer'>
            <description xmlns='urn:xmpp:jingle:apps:filetransfer:5'>
              <offer>
                <file>
                  <date>1969-07-21T02:56:15Z</date>
                  <desc>This is a photo of my cat.</desc>
                  <name>cat.jpg</name>
                  <size>1024</size>
                  <hash xmlns='urn:xmpp:hashes:1' algo='sha-1'>552da749</hash>
                </file>
              </offer>
            </description>
          </content>
        </jingle>
        XML

      jingle.action.should eq "session-initiate"
      jingle.initiator.should eq "juliet@capulet.lit/balcony"
      jingle.sid.should eq "a73sjjvkla37jfea"
      jingle.contents.size.should eq 1
      content = jingle.contents[0]
      content.creator.should eq "initiator"
      content.name.should eq "a-file-offer"
      ft = content.description.as(XMPP::Stanza::JingleFileTransfer)
      ft.offer.should eq true
      file = ft.file.not_nil!
      file.name.should eq "cat.jpg"
      file.size.should eq 1024
      file.date.should eq "1969-07-21T02:56:15Z"
      file.desc.should eq "This is a photo of my cat."
      file.hash.should eq "552da749"
    end

    it "parses an in-band bytestream content" do
      jingle = XMPP::Stanza::Jingle.new(<<-XML)
        <jingle xmlns='urn:xmpp:jingle:1'
                action='session-initiate'
                initiator='romeo@montague.lit/orchard'
                sid='a1b2c3'>
          <content creator='initiator' name='in-band-ibb'>
            <description xmlns='urn:xmpp:jingle:apps:ibb:1'>
              <block-size>4096</block-size>
            </description>
          </content>
        </jingle>
        XML

      ibb = jingle.contents[0].description.as(XMPP::Stanza::JingleIBB)
      ibb.block_size.should eq 4096
    end
  end

  describe XMPP::Stanza::JingleFileTransfer do
    it "serializes a file offer" do
      ft = XMPP::Stanza::JingleFileTransfer.new
      ft.offer = true
      file = XMPP::Stanza::JingleFile.new
      file.name = "notes.txt"
      file.size = 128_i64
      ft.file = file

      xml = XML.build { |x| ft.to_xml(x) }
      xml.should contain "urn:xmpp:jingle:apps:filetransfer:5"
      xml.should contain "<offer>"
      xml.should contain "<name>notes.txt</name>"
      xml.should contain "<size>128</size>"
    end
  end

  describe XMPP::Jingle do
    it "builds a session-initiate offer with optional in-band bytestream" do
      client = JingleStubClient.new
      jingle = XMPP::Jingle.new(client)

      iq = jingle.build_offer("peer@example.org", "sid-1", "report.pdf", size: 2048_i64)
      iq.type.should eq "set"
      iq.to.should eq "peer@example.org"

      j = iq.payload.as(XMPP::Stanza::Jingle)
      j.action.should eq "session-initiate"
      j.contents.size.should eq 1
      ft = j.contents[0].description.as(XMPP::Stanza::JingleFileTransfer)
      ft.file.not_nil!.name.should eq "report.pdf"
      ft.file.not_nil!.size.should eq 2048

      iq = jingle.build_offer("peer@example.org", "sid-2", "report.pdf", ibb_block_size: 4096)
      j = iq.payload.as(XMPP::Stanza::Jingle)
      j.contents.size.should eq 2
      j.contents[1].description.as(XMPP::Stanza::JingleIBB).block_size.should eq 4096
    end
  end
end
