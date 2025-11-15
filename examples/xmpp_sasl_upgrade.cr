require "../src/cr-xmpp"

# Example demonstrating XEP-0480: SASL Upgrade Tasks
# This allows clients to help servers upgrade to stronger authentication mechanisms
# without requiring password resets.
#
# How it works:
# 1. Client authenticates with an existing mechanism (e.g., SCRAM-SHA-1)
# 2. Server requests upgrade tasks (e.g., UPGR-SCRAM-SHA-256, UPGR-SCRAM-SHA-512)
# 3. Client computes new hashes using the original password
# 4. Server stores the new hashes for future authentications
#
# This example demonstrates the upgrade process when connecting to a server
# that supports SASL upgrade tasks.

config = XMPP::Config.new(
  host: ENV["XMPP_HOST"]? || "localhost",
  jid: ENV["XMPP_JID"]? || "test@localhost",
  password: ENV["XMPP_PASSWORD"]? || "test",
  tls: true, # TLS is strongly recommended for secure upgrades
  log_file: STDOUT,
  # Start with an older mechanism to demonstrate upgrade
  # In production, you'd typically use the strongest available
  sasl_auth_order: [
    XMPP::AuthMechanism::SCRAM_SHA_1_PLUS,   # Authenticate with SHA-1
    XMPP::AuthMechanism::SCRAM_SHA_256_PLUS, # But be ready to upgrade
    XMPP::AuthMechanism::SCRAM_SHA_512_PLUS,
    XMPP::AuthMechanism::SCRAM_SHA_1,
    XMPP::AuthMechanism::SCRAM_SHA_256,
    XMPP::AuthMechanism::SCRAM_SHA_512,
  ]
)

router = XMPP::Router.new

router.presence do |_, prs|
  if msg = prs.as?(XMPP::Stanza::Presence)
    puts "✓ Presence received: #{msg.from}"
  end
end

router.message do |snd, pms|
  if msg = pms.as?(XMPP::Stanza::Message)
    puts "✓ Message from #{msg.from}: #{msg.body}"

    # Echo the message back
    reply = XMPP::Stanza::Message.new
    reply.to = msg.from
    reply.body = "Echo: #{msg.body}"
    snd.send reply
  end
end

puts "=" * 70
puts "XEP-0480: SASL Upgrade Tasks Example"
puts "=" * 70
puts ""
puts "This example demonstrates automatic SASL mechanism upgrades."
puts ""
puts "Configuration:"
puts "  Host: #{config.host}"
puts "  JID: #{config.jid}"
puts "  TLS: #{config.tls}"
puts "  Primary Auth: SCRAM-SHA-1-PLUS"
puts ""
puts "If the server supports upgrade tasks, the client will automatically:"
puts "  1. Authenticate using SCRAM-SHA-1-PLUS"
puts "  2. Detect available upgrade tasks (e.g., UPGR-SCRAM-SHA-256)"
puts "  3. Compute and send new hashes for stronger mechanisms"
puts "  4. Allow server to store hashes for future authentications"
puts ""
puts "NOTE: This library fully supports SASL2 (XEP-0388) and XEP-0480."
puts "If the server supports SASL2, the client will automatically:"
puts "  - Use modern SASL2 authentication flow"
puts "  - Request available upgrade tasks"
puts "  - Perform upgrades after successful authentication"
puts "If the server doesn't support SASL2, it falls back to legacy SASL."
puts ""
puts "Watch the logs below for upgrade task execution..."
puts "=" * 70
puts ""

begin
  client = XMPP::Client.new config, router
  sm = XMPP::StreamManager.new client

  # The client will automatically handle upgrade tasks if the server requests them
  # Check the logs to see:
  # - Which mechanism was used for authentication
  # - Which upgrade tasks were performed
  # - The computed hashes sent to the server

  puts "Connecting and authenticating..."

  # Check if server advertises upgrade tasks
  if mechs = client.session.features.mechanisms
    if mechs.upgrade_tasks.empty?
      puts ""
      puts "⚠️  Server does not advertise XEP-0480 upgrade tasks"
      puts "    Available mechanisms: #{mechs.mechanism.join(", ")}"
      puts "    No upgrades will be performed (this is normal)"
      puts ""
    else
      puts ""
      puts "✓ Server supports XEP-0480 upgrade tasks!"
      puts "  Available upgrades: #{mechs.upgrade_tasks.join(", ")}"
      puts ""
    end
  end

  sm.run
rescue ex : XMPP::AuthenticationError
  puts ""
  puts "Authentication failed: #{ex.message}"
  puts ""
  puts "Note: This example requires a server that supports:"
  puts "  - SASL2 (XEP-0388) - Modern authentication framework"
  puts "  - XEP-0480 SASL Upgrade Tasks (optional)"
  puts ""
  puts "Most current XMPP servers don't support these yet."
  puts "The client will automatically fall back to legacy SASL"
  puts "if SASL2 is not available."
  exit 1
rescue ex
  puts ""
  puts "Error: #{ex.message}"
  exit 1
end
