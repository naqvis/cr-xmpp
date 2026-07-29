require "./spec_helper"

private class OneByteAtATimeIO < IO
  def initialize(input : String)
    @input = IO::Memory.new(input)
  end

  def read(slice : Bytes) : Int32
    @input.read(slice[0, Math.min(slice.size, 1)])
  end

  def write(slice : Bytes) : Nil
    raise IO::Error.new("read-only test stream")
  end
end

private class CountingReadIO < IO
  getter reads = 0

  def initialize(input : String)
    @input = IO::Memory.new(input)
  end

  def read(slice : Bytes) : Int32
    @reads += 1
    @input.read(slice)
  end

  def write(slice : Bytes) : Nil
    raise IO::Error.new("read-only test stream")
  end
end

describe XMPP::XMLStreamReader do
  it "parses a stream opening tag followed by coalesced stream features" do
    io = IO::Memory.new(
      "<?xml version='1.0'?><stream:stream from='example.org' id='abc' " \
      "xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>" \
      "<stream:features><mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>" \
      "<mechanism>SCRAM-SHA-256</mechanism></mechanisms></stream:features>"
    )
    reader = XMPP::XMLStreamReader.new(io, read_size: 7)

    stream = reader.read_node
    stream.name.should eq "stream"
    stream["id"].should eq "abc"

    features = reader.read_node
    features.name.should eq "features"
    features.namespace.try(&.href).should eq XMPP::Stanza::NS_STREAM
    features.first_element_child.try(&.name).should eq "mechanisms"
  end

  it "retains multiple coalesced stanzas" do
    io = IO::Memory.new("<message id='1'><body>one</body></message><presence id='2'/>")
    reader = XMPP::XMLStreamReader.new(io)

    reader.read_node["id"].should eq "1"
    reader.read_node["id"].should eq "2"
  end

  it "handles delimiters inside attributes, comments, CDATA, and text" do
    xml = "<message data='>'><!-- <fake/> --><body><![CDATA[<hello>]]></body></message>"
    node = XMPP::XMLStreamReader.new(IO::Memory.new(xml), read_size: 3).read_node

    node["data"].should eq ">"
    node.first_element_child.try(&.content).should eq "<hello>"
  end

  it "rejects DTD declarations" do
    reader = XMPP::XMLStreamReader.new(IO::Memory.new("<!DOCTYPE message><message/>"))

    expect_raises(XMPP::StreamParseError, /DTD declarations/) { reader.read_node }
  end

  it "enforces the configured element size limit" do
    reader = XMPP::XMLStreamReader.new(
      IO::Memory.new("<message><body>#{"x" * 128}</body></message>"),
      max_element_size: 64,
      read_size: 16
    )

    expect_raises(XMPP::StanzaTooLarge) { reader.read_node }
  end

  it "rejects malformed XML instead of recovering it" do
    reader = XMPP::XMLStreamReader.new(IO::Memory.new("<message><body></message>"))

    expect_raises(XMPP::StreamParseError, /Mismatched/) { reader.read_node }
  end

  it "scans a large element once under one-byte network fragmentation" do
    body = "x" * (128 * 1024)
    io = OneByteAtATimeIO.new("<message><body>#{body}</body></message>")
    reader = XMPP::XMLStreamReader.new(io, max_element_size: 256 * 1024)

    reader.read_node.first_element_child.try(&.content).should eq body
  end

  it "reuses coalesced input across thousands of stanzas without rereading it" do
    stanza_count = 2_000
    input = String.build do |xml|
      stanza_count.times { |index| xml << "<presence id='" << index << "'/>" }
    end
    io = CountingReadIO.new(input)
    reader = XMPP::XMLStreamReader.new(io)

    stanza_count.times do |index|
      reader.read_node["id"].should eq index.to_s
    end

    # The reader should consume network-sized chunks, not perform one read per
    # stanza or rebuild the unread stream for every element.
    io.reads.should be < 20
  end
end
