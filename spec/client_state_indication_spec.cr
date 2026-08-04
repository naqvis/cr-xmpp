require "./spec_helper"

private class RecordingClient < XMPP::Client
  getter sent : Array(String) = [] of String

  def initialize
    super(XMPP::Config.new("test@localhost", "test", "localhost"), XMPP::Router.new)
  end

  def send(packet : String)
    @sent << packet
  end
end

describe XMPP::ClientStateIndication do
  it "sends the active nonza" do
    client = RecordingClient.new
    XMPP::ClientStateIndication.new(client).active
    client.sent.should eq [%(<active xmlns="urn:xmpp:csi:0"/>\n)]
  end

  it "sends the inactive nonza" do
    client = RecordingClient.new
    XMPP::ClientStateIndication.new(client).inactive
    client.sent.should eq [%(<inactive xmlns="urn:xmpp:csi:0"/>\n)]
  end
end
