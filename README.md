# Crystal XMPP

![CI](https://github.com/naqvis/cr-xmpp/workflows/CI/badge.svg)
[![GitHub release](https://img.shields.io/github/release/naqvis/cr-xmpp.svg)](https://github.com/naqvis/cr-xmpp/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://naqvis.github.io/cr-xmpp/)

**Pure Crystal** XMPP Shard, focusing on simplicity, simple automation, and IoT.

The goal is to make simple to write simple XMPP clients and components. It features:

- Fully OOP
- Aims at being XMPP compliant
- Event Based
- Easy to extend
- For automation (like for example monitoring of an XMPP service),
- For building connected "things" by plugging them on an XMPP server,
- For writing simple chatbot to control a service or a thing,
- For writing XMPP servers components.

You can basically do everything you want with `cr-xmpp`. It fully supports XMPP Client and components specification, and also a wide range of extensions (XEPs). And it's very easy to extend :)

**Dependencies:**

- `openssl_ext` - Required for channel binding support (provides extended OpenSSL functionality)

## Supported specifications

📋 **[Complete Protocol Support Matrix →](PROTOCOL.md)**

For detailed version information, implementation status, and planned features, see [PROTOCOL.md](PROTOCOL.md).

### Clients

- [RFC 6120: XMPP Core](https://xmpp.org/rfcs/rfc6120.html)
- [RFC 6121: XMPP Instant Messaging and Presence](https://xmpp.org/rfcs/rfc6121.html)

### Components

- [XEP-0114: Jabber Component Protocol](https://xmpp.org/extensions/xep-0114.html)
- [XEP-0355: Namespace Delegation](https://xmpp.org/extensions/xep-0355.html) - Component-side support
- [XEP-0356: Privileged Entity](https://xmpp.org/extensions/xep-0356.html) - Component-side support

### XEP Extensions

- [XEP-0030 - Service Discovery](http://www.xmpp.org/extensions/xep-0030.html)
- [XEP-0045 - Multi-User Chat - 19.1](http://www.xmpp.org/extensions/xep-0045.html)
- [XEP-0060 - Publish-Subscribe](http://xmpp.org/extensions/xep-0060.html)
- [XEP-0066 - Out of Band Data](https://xmpp.org/extensions/xep-0066.html)
- [XEP-0085 - Chat State Notifications](https://xmpp.org/extensions/xep-0085.html)
- [XEP-0092 - Software Version](https://xmpp.org/extensions/xep-0092.html)
- [XEP-0107 - User Mood](https://xmpp.org/extensions/xep-0107.html)
- [XEP-0153 - vCard-Based Avatars](https://xmpp.org/extensions/xep-0153.html)
- [XEP-0184 - Message Delivery Receipts](https://xmpp.org/extensions/xep-0184.html)
- [XEP-0198 - Stream Management](https://xmpp.org/extensions/xep-0198.html#feature)
- [XEP-0199 - XMPP Ping](https://xmpp.org/extensions/xep-0199.html)
- [XEP-0203 - Delayed Delivery](http://www.xmpp.org/extensions/xep-0203.html)
- [XEP-0333 - Chat Markers](https://xmpp.org/extensions/xep-0333.html)
- [XEP-0334 - Message Processing Hints](https://xmpp.org/extensions/xep-0334.html)
- [XEP-0388 - Extensible SASL Profile](https://xmpp.org/extensions/xep-0388.html)
- [XEP-0440 - SASL Channel-Binding Type Capability](https://xmpp.org/extensions/xep-0440.html)
- [XEP-0474 - SASL SCRAM Downgrade Protection](https://xmpp.org/extensions/xep-0474.html)
- [XEP-0480 - SASL Upgrade Tasks](https://xmpp.org/extensions/xep-0480.html)

### Security & Channel Binding

- [RFC 5929 - Channel Bindings for TLS](https://datatracker.ietf.org/doc/html/rfc5929)
  - `tls-unique` for TLS ≤ 1.2
  - `tls-server-end-point` for TLS ≤ 1.2 and 1.3
- [RFC 9266 - Channel Bindings for TLS 1.3](https://datatracker.ietf.org/doc/html/rfc9266)
  - `tls-exporter` for TLS 1.3

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     cr-xmpp:
       github: naqvis/cr-xmpp
   ```

2. Run `shards install`

   This will automatically install the required `openssl_ext` dependency for channel binding support.

## Usage

```crystal
require "cr-xmpp"

config = XMPP::Config.new(
  host: "localhost",
  jid: "test@localhost",
  password: "test",
  tls: true,          # Enable TLS for secure connections (required for channel binding)
  log_file: STDOUT,   # Capture all out-going and in-coming messages
  auto_presence: true, # Automatically send initial presence after connection (default: true)
                      # Set to false for invisible login or manual presence control
  # Order of SASL Authentication Mechanism, first matched method supported by server will be used
  # for authentication. Below is default order that will be used if `sasl_auth_order` param is not set.
  # SCRAM-PLUS variants (with channel binding) are preferred for enhanced security
  sasl_auth_order: [XMPP::AuthMechanism::SCRAM_SHA_512_PLUS, XMPP::AuthMechanism::SCRAM_SHA_256_PLUS,
                    XMPP::AuthMechanism::SCRAM_SHA_1_PLUS, XMPP::AuthMechanism::SCRAM_SHA_512,
                    XMPP::AuthMechanism::SCRAM_SHA_256, XMPP::AuthMechanism::SCRAM_SHA_1,
                    XMPP::AuthMechanism::DIGEST_MD5, XMPP::AuthMechanism::PLAIN,
                    XMPP::AuthMechanism::ANONYMOUS]
)

router = XMPP::Router.new

# router.on "presence" do |_, p|  # OR
router.presence do |_, p|
  if (msg = p.as?(XMPP::Stanza::Presence))
    puts msg
  else
    puts "Ignoring Packet: #{p}"
  end
end

# router.when "chat" do |s, p| # OR
router.message do |s, p|
  handle_message(s, p)
end

# OR
# router.on "message", ->handle_message(XMPP::Sender, XMPP::Stanza::Packet)

client = XMPP::Client.new config, router
# If you pass the client to a connection manager, it will handle the reconnect policy
# for you automatically
sm = XMPP::StreamManager.new client
sm.run


def handle_message(s : XMPP::Sender, p : XMPP::Stanza::Packet)
  if (msg = p.as?(XMPP::Stanza::Message))
    puts "Got message: #{msg.body}"
    reply = XMPP::Stanza::Message.new
    reply.to = msg.from
    reply.body = "#{msg.body}"
    s.send reply
  else
    puts "Ignoring Packet: #{p}"
  end
end
```

Refer to **examples** for more usage details.

## Development & Testing

A Docker Compose setup is provided for easy testing with a local XMPP server:

```bash
# 1. Generate SSL certificates (required for TLS/channel binding)
./docker/prosody/generate-certs.sh

# 2. Start XMPP server (test users are created automatically)
docker compose up -d

# 3. Wait a few seconds for server to be ready
sleep 5

# 4. Run examples
XMPP_HOST=localhost XMPP_JID=test@localhost XMPP_PASSWORD=test crystal run examples/xmpp_echo.cr

# Run SASL upgrade example
XMPP_HOST=localhost XMPP_JID=test@localhost XMPP_PASSWORD=test crystal run examples/xmpp_sasl_upgrade.cr

# View logs
docker compose logs -f prosody

# Stop server
docker compose down
```

**Test accounts created automatically:**

- `admin@localhost` (password: `admin123`)
- `test@localhost` (password: `test`)
- `user2@localhost` (password: `password2`)

**Note:** On ARM64/Apple Silicon, Prosody runs via Rosetta 2 emulation (automatic in Docker Desktop).

See [docker/README.md](docker/README.md) for detailed documentation.

## Channel Binding for Enhanced Security

This library supports **channel binding** for TLS connections, providing protection against man-in-the-middle attacks by cryptographically binding the SASL authentication to the underlying TLS connection.

### What is Channel Binding?

Channel binding ensures that the authentication credentials are tied to the specific TLS connection, preventing attackers from intercepting and relaying authentication over a different connection.

### Supported Channel Binding Types

- **tls-exporter** (RFC 9266) - For TLS 1.3 connections
- **tls-server-end-point** (RFC 5929) - For TLS 1.2, 1.3 (fully implemented)
- **tls-unique** (RFC 5929) - For TLS ≤ 1.2 (requires OpenSSL FFI)

### SCRAM-PLUS Authentication

Channel binding is used with SCRAM mechanisms that have the `-PLUS` suffix:

- ✅ `SCRAM-SHA-512-PLUS` (most secure, recommended)
- ✅ `SCRAM-SHA-256-PLUS`
- ✅ `SCRAM-SHA-1-PLUS`

**Implementation Status:**

- ✅ All SCRAM-PLUS variants fully supported
- ✅ XEP-0388: Extensible SASL Profile (SASL2)
- ✅ XEP-0440: Channel binding type capability
- ✅ XEP-0474: Downgrade protection
- ✅ tls-server-end-point (fully functional for TLS 1.2/1.3)
- ⚠️ tls-unique and tls-exporter (require OpenSSL FFI extensions)

These mechanisms are **automatically preferred** when:

- TLS is enabled (`tls: true`)
- Server advertises support for -PLUS variants
- Channel binding data is available

### Automatic Downgrade Protection (XEP-0474)

The library automatically detects and warns about potential downgrade attacks where an attacker tries to force the use of weaker authentication mechanisms. When a SCRAM-PLUS mechanism is available but a non-PLUS variant is being used, a warning is logged.

### Usage Example

```crystal
require "cr-xmpp"

# Channel binding is enabled automatically with TLS
config = XMPP::Config.new(
  jid: "user@example.com",
  password: "password",
  host: "example.com",
  tls: true  # Required for channel binding
)

client = XMPP::Client.new(config)
# Authentication will automatically use SCRAM-PLUS if server supports it
```

### Server Requirements

Channel binding works automatically when TLS is enabled and the server supports SCRAM-PLUS mechanisms.

## Modern SASL Authentication (XEP-0388)

This library fully supports **SASL2 (Extensible SASL Profile)**, the modern XMPP authentication framework that provides:

- **Reduced round trips** - No stream restart after authentication
- **Inline features** - Negotiate resource binding and stream management during auth
- **User agent tracking** - Inform servers about client software and devices
- **Task support** - Enable 2FA, password changes, and mechanism upgrades
- **Automatic fallback** - Seamlessly falls back to legacy SASL if server doesn't support SASL2

The library automatically detects SASL2 support and uses it when available, providing a transparent upgrade path.

## SASL Mechanism Upgrades (XEP-0480)

This library fully supports **SASL mechanism upgrades**, allowing clients to help servers migrate to stronger authentication mechanisms without requiring password resets.

**Now fully functional with SASL2!** All XEP-0480 stanzas, parsing, upgrade logic, and SASL2 integration are implemented and tested.

The library automatically handles SASL mechanism upgrades when supported by the server.
SASL upgrades happen automatically when the server supports them. See `examples/xmpp_sasl_upgrade.cr` for usage.

## Service Discovery for Components (XEP-0030)

Components have full support for **Service Discovery**, allowing them to automatically respond to disco#info and disco#items queries.

### Features

- **Automatic disco handling** - Components automatically respond to discovery queries
- **Multiple identities** - Support for multiple identity categories/types
- **Feature registration** - Easily register supported protocols and features
- **Items support** - Advertise associated items (rooms, channels, nodes, etc.)
- **Node support** - Hierarchical item structures with node-based queries
- **Zero configuration** - Basic disco works out of the box

### Usage

```crystal
# Create component with basic identity
options = XMPP::ComponentOptions.new(
  domain: "gateway.example.com",
  secret: "secret",
  host: "localhost",
  port: 5347,
  name: "IRC Gateway",
  category: "gateway",
  type: "irc"
)

component = XMPP::Component.new(options, router)

# Add additional identities
component.disco_info.add_identity("conference", "text", "Chat Rooms")

# Add supported features
component.disco_info.add_features([
  "http://jabber.org/protocol/muc",
  "jabber:iq:register",
  "jabber:iq:search"
])

# Add items (e.g., available IRC networks)
component.disco_items.add_item("gateway.example.com", "irc.freenode.net", "Freenode")
component.disco_items.add_item("gateway.example.com", "irc.libera.chat", "Libera Chat")

# Add hierarchical items (items within a node)
component.disco_items.add_node_item(
  "irc.freenode.net",
  "gateway.example.com",
  "irc.freenode.net/#crystal-lang",
  "#crystal-lang channel"
)

# Component now automatically responds to:
# - <iq type='get'><query xmlns='http://jabber.org/protocol/disco#info'/></iq>
# - <iq type='get'><query xmlns='http://jabber.org/protocol/disco#items'/></iq>
```

### Node Support

Components can define node-specific disco information:

```crystal
# Create node-specific disco info
node_info = XMPP::ComponentDisco::DiscoNodeInfo.new
node_info.add_identity("automation", "command-list", "Available Commands")
node_info.add_feature("http://jabber.org/protocol/commands")

# Register the node
component.disco_info.add_node("http://jabber.org/protocol/commands", node_info)

# Now queries to this node will return node-specific information
```

### Example

See `examples/xmpp_component_disco.cr` for a complete demonstration.

## Component Delegation and Privileges

Components can handle delegated namespaces and access privileged data when the server grants permissions.

### Using Delegated Namespaces

```crystal
# Check if a namespace is delegated to your component
if component.delegation_manager.delegated?("http://jabber.org/protocol/pubsub")
  puts "Handling PubSub for this server"
end

# Process delegated stanzas by overriding the handler
def handle_delegated_iq(sender, wrapper_iq, original_iq)
  response = process_request(original_iq)
  wrapped = wrap_delegated_response(wrapper_iq.id, response, wrapper_iq.from)
  send(wrapped)
end
```

### Using Privileges

```crystal
# Grant privileges manually (for testing)
component.grant_privilege("roster", "both", push: true)
component.grant_privilege("message", "outgoing")

# Access user rosters
if component.privilege_manager.can_get_roster?
  iq_id = component.get_user_roster("user@example.com")
end

# Send messages on behalf of users
if component.privilege_manager.can_send_messages?
  component.send_privileged_message(
    from_jid: "user@example.com",
    to_jid: "contact@example.com",
    body: "Notification"
  )
end
```

See `examples/xmpp_component_delegation_privilege.cr` for a complete example.

## Publish-Subscribe (XEP-0060)

The library provides comprehensive support for **Publish-Subscribe**, enabling event-driven communication patterns for content syndication, presence extensions, and real-time notifications.

### Features

- **Subscription Management** - Subscribe/unsubscribe to nodes
- **Subscription Tracking** - Monitor subscription states (subscribed, pending, unconfigured)
- **Affiliation Management** - Track node affiliations (owner, publisher, member, outcast)
- **Item Retrieval** - Fetch items from nodes with filtering options
- **Publishing** - Publish items to nodes
- **Retraction** - Remove items from nodes
- **PEP Integration** - Full support for Personal Eventing Protocol (User Tune, Mood, etc.)

### Subscription Management

```crystal
# Subscribe to a node
iq = XMPP::Stanza::IQ.new
iq.type = "set"
iq.to = "pubsub.example.com"

pubsub = XMPP::Stanza::PubSub.new
subscribe = XMPP::Stanza::Subscribe.new
subscribe.node = "news_feed"
subscribe.jid = "user@example.com"
pubsub.subscribe = subscribe
iq.payload = pubsub

# Unsubscribe from a node
unsubscribe = XMPP::Stanza::Unsubscribe.new
unsubscribe.node = "news_feed"
unsubscribe.jid = "user@example.com"
unsubscribe.subid = "subscription-id"  # Optional
pubsub.unsubscribe = unsubscribe
```

### Retrieving Subscriptions and Affiliations

```crystal
# Get all subscriptions
iq = XMPP::Stanza::IQ.new
iq.type = "get"
iq.to = "pubsub.example.com"

pubsub = XMPP::Stanza::PubSub.new
subscriptions = XMPP::Stanza::Subscriptions.new
pubsub.subscriptions = subscriptions
iq.payload = pubsub

# Parse subscription response
pubsub = iq.payload.as(XMPP::Stanza::PubSub)
if subs = pubsub.subscriptions
  subs.subscriptions.each do |sub|
    puts "Node: #{sub.node}, State: #{sub.subscription}"
  end
end

# Get all affiliations
affiliations = XMPP::Stanza::Affiliations.new
pubsub.affiliations = affiliations

# Parse affiliation response
if affils = pubsub.affiliations
  affils.affiliations.each do |affil|
    puts "Node: #{affil.node}, Role: #{affil.affiliation}"
  end
end
```

### Item Retrieval

```crystal
# Retrieve items from a node
iq = XMPP::Stanza::IQ.new
iq.type = "get"
iq.to = "pubsub.example.com"

pubsub = XMPP::Stanza::PubSub.new
items = XMPP::Stanza::Items.new
items.node = "news_feed"
items.max_items = "10"  # Optional: limit number of items
pubsub.items = items
iq.payload = pubsub

# Parse items response
pubsub = iq.payload.as(XMPP::Stanza::PubSub)
if items = pubsub.items
  items.items.each do |item|
    puts "Item ID: #{item.id}"
    # Access PEP payloads
    if tune = item.tune
      puts "Now playing: #{tune.artist} - #{tune.title}"
    end
  end
end
```

### Publishing and Retracting

```crystal
# Publish an item
pubsub = XMPP::Stanza::PubSub.new
publish = XMPP::Stanza::Publish.new
publish.node = "news_feed"

item = XMPP::Stanza::Item.new
item.id = "item-123"
# Add payload (e.g., User Tune)
tune = XMPP::Stanza::Tune.new
tune.artist = "The Beatles"
tune.title = "Hey Jude"
item.tune = tune

publish.item = item
pubsub.publish = publish

# Retract an item
retract = XMPP::Stanza::Retract.new
retract.node = "news_feed"
retract.notify = "true"  # Notify subscribers

item = XMPP::Stanza::Item.new
item.id = "item-123"
retract.item = item
pubsub.retract = retract
```

### Subscription States

- `none` - No subscription
- `pending` - Subscription awaiting approval
- `subscribed` - Active subscription
- `unconfigured` - Subscription requires configuration

### Affiliation Types

- `owner` - Full control over the node
- `publisher` - Can publish items
- `publish-only` - Can publish but not subscribe
- `member` - Can subscribe (whitelist access)
- `outcast` - Banned from the node
- `none` - No affiliation

### Example

See `examples/pubsub_example.cr` for a complete demonstration of all PubSub features.

## Development

XMPP stanzas are basic and extensible XML elements. Stanzas (or sometimes special stanzas called 'nonzas') are used to
leverage the XMPP protocol features. During a session, a client (or a component) and a server will be exchanging stanzas
back and forth.

At a low-level, stanzas are XML fragments. However, this shard provides the building blocks to interact with
stanzas at a high-level, providing a Crystal-friendly API.

The `XMPP::Stanza` module provides support for XMPP stream parsing, encoding and decoding of XMPP stanza. It is a
bridge between high-level Crystal classes and low-level XMPP protocol.

Parsing, encoding and decoding is automatically handled by Crystal XMPP client shard. As a developer, you will
generally manipulates only the high-level classes provided by the `XMPP::Stanza` module.

The XMPP protocol, as the name implies is extensible. If your application is using custom stanza extensions, you can
implement your own extensions directly.

# Custom Stanza Support

Below example show how to implement a custom extension for your own client, without having to modify or fork Crystal XMPP shard.

```Crystal
class CustomExtension < Extension
    include IQPayload
    class_getter xml_name : XMLName = XMLName.new("my:custom:payload query")
    property node : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}, expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) &&
                                                                             (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
      case child.name
        when "item" then cls.node = child.content
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        elem.element("node") { elem.text node } unless node.blank?
      end
    end

    def namespace : String
      @@xml_name.space
    end

    def name : String
      @@xml_name.local
    end
  end

  Registry.map_extension(PacketType::IQ, XMLName.new("my:custom:payload", "query"), CustomExtension)
```

## Contributing

1. Fork it (<https://github.com/naqvis/cr-xmpp/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Ali Naqvi](https://github.com/naqvis) - creator and maintainer
