[![Build Status](https://travis-ci.org/naqvis/cr-xmpp.svg?branch=master)](https://travis-ci.org/naqvis/cr-xmpp)
[![GitHub release](https://img.shields.io/github/release/naqvis/cr-xmpp.svg)](https://github.com/naqvis/cr-xmpp/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://naqvis.github.io/cr-xmpp/)

# Crystal XMPP

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

**This Shard does not have any other dependencies.**

## Supported specifications

### Clients

- [RFC 6120: XMPP Core](https://xmpp.org/rfcs/rfc6120.html)
- [RFC 6121: XMPP Instant Messaging and Presence](https://xmpp.org/rfcs/rfc6121.html)

### Components

  - [XEP-0114: Jabber Component Protocol](https://xmpp.org/extensions/xep-0114.html)
  - [XEP-0355: Namespace Delegation](https://xmpp.org/extensions/xep-0355.html)
  - [XEP-0356: Privileged Entity](https://xmpp.org/extensions/xep-0356.html)

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
  
## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     cr-xmpp:
       github: your-github-user/cr-xmpp
   ```

2. Run `shards install`

## Usage

```crystal
require "cr-xmpp"

config = XMPP::Config.new(
  host: "localhost",
  jid: "test@localhost",
  password: "test",
  log_file: STDOUT   # Capture all out-going and in-coming messages

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
      raise "Invalid node(#{node.name}, expecting #{@@xml_name.to_s}" unless (node.namespace.try &.href == @@xml_name.space) &&
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
