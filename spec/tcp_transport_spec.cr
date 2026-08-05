require "./spec_helper"
require "socket"

describe XMPP::TcpTransport do
  it "connects, writes through to, and reads from the TCP socket" do
    server = TCPServer.new("127.0.0.1", 0)
    port = server.local_address.as(Socket::IPAddress).port
    accepted = Channel(TCPSocket).new(1)
    spawn do
      client = server.accept
      client.sync = true
      accepted.send(client)
      client.write("hello".to_slice)
      buf = Bytes.new(4)
      client.read_fully(buf)
      client.write(buf)
    end

    config = XMPP::Config.new(jid: "test@example.org", password: "secret", host: "127.0.0.1", port: port, io_timeout: 3)
    transport = XMPP::TcpTransport.open(config)

    buffer = Bytes.new(8)
    transport.read(buffer).should eq 5
    String.new(buffer[0, 5]).should eq "hello"
    transport.encrypted?.should be_false
    transport.tls_socket.should be_nil

    transport.write("ping".to_slice)
    peer = accepted.receive
    peer.sync = true
    buffer2 = Bytes.new(8)
    count = transport.read(buffer2)
    String.new(buffer2[0, count]).should eq "ping"
  ensure
    transport.try(&.close)
    server.try(&.close)
  end
end
