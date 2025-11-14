require "../src/cr-xmpp"

config = XMPP::Config.new(
  host: "localhost",
  jid: "test@localhost",
  password: "test",
  log_file: STDOUT
)

router = XMPP::Router.new
# router.on "presence" do |_, p|
router.presence do |_, p|
  if msg = p.as?(XMPP::Stanza::Presence)
    puts msg
  else
    puts "Ignoring Packet: #{p}"
  end
end

# router.when "chat" do |s, p|
router.message do |s, p|
  handle_message(s, p)
end

# router.on "message", ->handle_message(XMPP::Sender, XMPP::Stanza::Packet)

def handle_message(s : XMPP::Sender, p : XMPP::Stanza::Packet)
  if msg = p.as?(XMPP::Stanza::Message)
    puts "Got message: #{msg.body}"
    reply = XMPP::Stanza::Message.new
    reply.to = msg.from
    reply.body = "#{msg.body}"
    s.send reply
  else
    puts "Ignoring Packet: #{p}"
  end
end

client = XMPP::Client.new config, router
# If you pass the client to a connection manager, it will handle the reconnect policy
# for you automatically
sm = XMPP::StreamManager.new client
sm.run
