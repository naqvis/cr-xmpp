require "./spec_helper"

describe XMPP::Transport::ReadBuffer do
  it "drains pushed bytes and returns 0 when empty" do
    buffer = XMPP::Transport::ReadBuffer.new
    buffer.push("abc")
    target = Bytes.new(8)
    buffer.drain(target).should eq 3
    String.new(target[0, 3]).should eq "abc"
    buffer.drain(target).should eq 0
  end

  it "serves one read from multiple pushes" do
    buffer = XMPP::Transport::ReadBuffer.new
    buffer.push("ab")
    buffer.push("cd")
    target = Bytes.new(2)
    buffer.drain(target).should eq 2
    String.new(target).should eq "ab"
    buffer.drain(target).should eq 2
    String.new(target).should eq "cd"
  end

  it "serves one push across multiple reads" do
    buffer = XMPP::Transport::ReadBuffer.new
    buffer.push("abcd")
    target = Bytes.new(2)
    buffer.drain(target).should eq 2
    String.new(target).should eq "ab"
    buffer.drain(target).should eq 2
    String.new(target).should eq "cd"
    buffer.drain(target).should eq 0
  end

  it "accepts raw byte slices" do
    buffer = XMPP::Transport::ReadBuffer.new
    buffer.push("abc".to_slice)
    target = Bytes.new(8)
    buffer.drain(target).should eq 3
    String.new(target[0, 3]).should eq "abc"
  end
end
