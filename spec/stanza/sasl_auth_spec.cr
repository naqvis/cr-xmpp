require "../spec_helper"

module XMPP::Stanza
  it "Check that we can detect optional session from advertised stream features" do
    stream_features = StreamFeatures.new
    session = StreamSession.new(true)
    stream_features.session = session

    xml = stream_features.to_xml
    parsed_stream = StreamFeatures.new xml

    fail "Session should be optional" unless parsed_stream.session.try &.optional
  end

  it "Check that the Session tag can be used in IQ decoding" do
    iq = IQ.new
    iq.type = IQ_TYPE_SET
    iq.id = "session"
    iq.payload = StreamSession.new(true)

    parsed_iq = IQ.new iq.to_xml
    session = parsed_iq.payload
    fail "Missing session payload" if session.nil? || !session.is_a?(StreamSession)
    session = session.as(StreamSession)
    fail "Session should be optional" unless session.optional
  end
end
