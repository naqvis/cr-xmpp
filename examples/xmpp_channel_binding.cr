require "../src/cr-xmpp"

# Example demonstrating SCRAM-PLUS authentication with channel binding
# This provides enhanced security by binding authentication to the TLS connection

config = XMPP::Config.new(
  host: ENV["XMPP_HOST"]? || "localhost",
  jid: ENV["XMPP_JID"]? || "test@localhost",
  password: ENV["XMPP_PASSWORD"]? || "test",
  tls: true, # TLS is required for channel binding
  log_file: STDOUT,
  # Prefer SCRAM-PLUS mechanisms for enhanced security
  sasl_auth_order: [
    XMPP::AuthMechanism::SCRAM_SHA_512_PLUS,
    XMPP::AuthMechanism::SCRAM_SHA_256_PLUS,
    XMPP::AuthMechanism::SCRAM_SHA_1_PLUS,
    XMPP::AuthMechanism::SCRAM_SHA_512,
    XMPP::AuthMechanism::SCRAM_SHA_256,
    XMPP::AuthMechanism::SCRAM_SHA_1,
  ]
)

router = XMPP::Router.new

router.presence do |_, p|
  if msg = p.as?(XMPP::Stanza::Presence)
    puts "Presence: #{msg.from} - #{msg.show}"
  end
end

router.message do |s, p|
  if msg = p.as?(XMPP::Stanza::Message)
    puts "Message from #{msg.from}: #{msg.body}"

    # Echo the message back
    reply = XMPP::Stanza::Message.new
    reply.to = msg.from
    reply.body = "Echo: #{msg.body}"
    s.send reply
  end
end

puts "Connecting with channel binding support..."
puts "Preferred auth mechanisms: SCRAM-SHA-512-PLUS, SCRAM-SHA-256-PLUS, SCRAM-SHA-1-PLUS"
puts ""

client = XMPP::Client.new config, router
sm = XMPP::StreamManager.new client

# The StreamManager will automatically use SCRAM-PLUS if the server supports it
# Check the logs to see which mechanism was actually used
sm.run
