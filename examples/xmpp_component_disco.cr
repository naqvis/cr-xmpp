require "../src/cr-xmpp"

# Example demonstrating XEP-0030 (Service Discovery) support for components
# This shows how components can automatically respond to disco#info and disco#items queries

# Component configuration
options = XMPP::ComponentOptions.new(
  domain: ENV["COMPONENT_DOMAIN"]? || "gateway.localhost",
  secret: ENV["COMPONENT_SECRET"]? || "secret",
  host: ENV["XMPP_HOST"]? || "localhost",
  port: (ENV["COMPONENT_PORT"]? || "5347").to_i,
  name: "Example IRC Gateway",
  category: "gateway",
  type: "irc",
  log_file: STDOUT
)

# Create router
router = XMPP::Router.new

# Handle messages
router.message do |_, packet|
  if msg = packet.as?(XMPP::Stanza::Message)
    puts "Received message from #{msg.from}: #{msg.body}"
  end
end

# Handle IQ requests (disco is handled automatically)
router.iq do |_, packet|
  if iq = packet.as?(XMPP::Stanza::IQ)
    puts "Received IQ: type=#{iq.type}, from=#{iq.from}"
  end
end

# Create component
component = XMPP::Component.new(options, router)

puts "=" * 70
puts "XEP-0030: Service Discovery Example for Components"
puts "=" * 70
puts ""
puts "Component Configuration:"
puts "  Domain: #{options.domain}"
puts "  Host: #{options.host}:#{options.port}"
puts "  Name: #{options.name}"
puts "  Category: #{options.category}"
puts "  Type: #{options.type}"
puts ""

# Add additional identities (components can have multiple identities)
component.disco_info.add_identity("conference", "text", "Chat Rooms")

# Add features the component supports
component.disco_info.add_features([
  "http://jabber.org/protocol/muc",
  "jabber:iq:register",
  "jabber:iq:search",
  "jabber:iq:version",
])

puts "Service Discovery Configuration:"
puts "  Identities: #{component.disco_info.identities.size}"
component.disco_info.identities.each do |identity|
  puts "    - #{identity.category}/#{identity.type}: #{identity.name}"
end
puts "  Features: #{component.disco_info.features.size}"
component.disco_info.features.each do |feature|
  puts "    - #{feature}"
end
puts ""

# Add some items (e.g., IRC channels available through the gateway)
component.disco_items.add_item("#{options.domain}", "irc.freenode.net", "Freenode IRC Network")
component.disco_items.add_item("#{options.domain}", "irc.libera.chat", "Libera Chat IRC Network")

# Add items to a specific node (hierarchical structure)
component.disco_items.add_node_item(
  "irc.freenode.net",
  "#{options.domain}",
  "irc.freenode.net/#crystal-lang",
  "#crystal-lang on Freenode"
)

puts "Items Configuration:"
puts "  Root items: #{component.disco_items.items.size}"
component.disco_items.items.each do |item|
  puts "    - #{item.node}: #{item.name}"
end
puts ""

# Add a node with its own disco info
node_info = XMPP::ComponentDisco::DiscoNodeInfo.new
node_info.add_identity("automation", "command-list", "Available Commands")
node_info.add_feature("http://jabber.org/protocol/commands")
component.disco_info.add_node("http://jabber.org/protocol/commands", node_info)

puts "Nodes Configuration:"
puts "  Nodes: #{component.disco_info.nodes.size}"
component.disco_info.nodes.each do |node, info|
  puts "    - #{node}: #{info.identities.size} identities, #{info.features.size} features"
end
puts ""

puts "=" * 70
puts "Component will automatically respond to:"
puts "  - disco#info queries (IQ get to disco#info namespace)"
puts "  - disco#items queries (IQ get to disco#items namespace)"
puts ""
puts "Test with another XMPP client:"
puts "  <iq type='get' to='#{options.domain}' id='disco1'>"
puts "    <query xmlns='http://jabber.org/protocol/disco#info'/>"
puts "  </iq>"
puts ""
puts "  <iq type='get' to='#{options.domain}' id='disco2'>"
puts "    <query xmlns='http://jabber.org/protocol/disco#items'/>"
puts "  </iq>"
puts "=" * 70
puts ""

begin
  puts "Connecting to XMPP server..."
  component.connect
  puts "Connected! Component is now responding to disco queries."
  puts "Press Ctrl+C to stop."
  puts ""

  # Keep the component running
  sleep
rescue ex
  puts ""
  puts "Error: #{ex.message}"
  puts ""
  puts "Make sure:"
  puts "  1. XMPP server is running"
  puts "  2. Component port (#{options.port}) is accessible"
  puts "  3. Component domain (#{options.domain}) is configured on the server"
  puts "  4. Component secret matches server configuration"
  exit 1
end
