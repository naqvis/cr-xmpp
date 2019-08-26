require "./spec_helper"

module XMPP
  it "Test Valid JIDs" do
    tests = [
      {jidstr: "test@domain.com", expected: JID.new("test", "domain.com", nil)},
      {jidstr: "test@domain.com/resource", expected: JID.new("test", "domain.com", "resource")},
      # resource can contain '/' or '@'
      {jidstr: "test@domain.com/a/b", expected: JID.new("test", "domain.com", "a/b")},
      {jidstr: "test@domain.com/a@b", expected: JID.new("test", "domain.com", "a@b")},
      {jidstr: "domain.com", expected: JID.new(nil, "domain.com", nil)},
    ]

    tests.each do |test|
      jid = JID.new(test[:jidstr])
      want = test[:expected]
      jid.node.should eq(want.node)
      jid.domain.should eq(want.domain)
      jid.resource.should eq(want.resource)
    end
  end

  it "Test Invalid JIDs" do
    tests = [
      "",
      "user@",
      "@domain.com",
      "user:name@domain.com",
      "user<name@domain.com",
      "test@domain.com@otherdomain.com",
      "test@domain com/resource",
    ]
    tests.each do |test|
      expect_raises(ArgumentError) do
        JID.new(test)
      end
    end
  end

  it "Test Full JID" do
    want = "test@domain.com/my resource"
    jid = JID.new(want)
    jid.full.should eq(want)
  end

  it "Test Bare JID" do
    want = "test@domain.com"
    full = want + "/my resource"
    jid = JID.new(full)
    jid.bare.should eq(want)
  end
end
