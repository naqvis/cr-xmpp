require "../src/cr-xmpp"

# # xmpp_component
# This component will connect to ejabberd and act as a subdomain "service" of your primary XMPP domain
# (in that case localhost).

# This component does nothing expect connect and show up in service discovery.

# To be able to connect this component, you need to add a listener to your XMPP server.

# Here is an example ejabberd configuration for that component listener:

# ```yaml
# listen:
# ...
#   -
#     port: 8888
#     module: ejabberd_service
#     password: "mypass"
# ```

# ejabberd will listen for a component (service) on port 8888 and allows it to connect using the
# secret "mypass".

OPTS = XMPP::ComponentOptions.new(
  domain: "service2.localhost",
  secret: "mypass",
  host: "localhost",
  port: 8888,
  name: "Test Component",
  category: "gateway",
  type: "service",
  log_file: STDOUT
)

router = XMPP::Router.new
router.on "message", ->handle_message(XMPP::Sender, XMPP::Stanza::Packet)
router.route(->disco_info(XMPP::Sender, XMPP::Stanza::Packet)).iq_namespaces([XMPP::Stanza::NS_DISCO_INFO])
router.route(->disco_items(XMPP::Sender, XMPP::Stanza::Packet)).iq_namespaces([XMPP::Stanza::NS_DISCO_ITEMS])
router.route(->version(XMPP::Sender, XMPP::Stanza::Packet)).iq_namespaces(["jabber:iq:version"])

component = XMPP::Component.new(OPTS, router)

# If you pass the component to a stream manager, it will handle the reconnect policy
# for you automatically.
sm = XMPP::StreamManager.new component

sm.run

def handle_message(s : XMPP::Sender, p : XMPP::Stanza::Packet)
  if msg = p.as?(XMPP::Stanza::Message)
    puts "Got message: #{msg.body}"
  else
    puts "Ignoring Packet: #{p}"
  end
end

def disco_info(s : XMPP::Sender, p : XMPP::Stanza::Packet)
  return unless p.is_a?(XMPP::Stanza::IQ)
  iq = p.as(XMPP::Stanza::IQ)
  return unless iq.type == "get"

  resp = XMPP::Stanza::IQ.new
  resp.type = "result"
  resp.from = iq.to
  resp.to = iq.from
  resp.id = iq.id
  resp.lang = "en"
  disco = resp.disco_info
  disco.add_identity(OPTS.name, OPTS.category, OPTS.type)
  disco.add_features([XMPP::Stanza::NS_DISCO_INFO, XMPP::Stanza::NS_DISCO_ITEMS, "jabber:iq:version", "urn:xmpp:delegation:1"])
  s.send resp
end

def disco_items(s : XMPP::Sender, p : XMPP::Stanza::Packet)
  return unless p.is_a?(XMPP::Stanza::IQ)
  iq = p.as(XMPP::Stanza::IQ)
  return unless iq.type == "get"
  return unless iq.payload.is_a?(XMPP::Stanza::DiscoItems)
  disco_items = iq.payload.try &.as(XMPP::Stanza::DiscoItems)

  resp = XMPP::Stanza::IQ.new
  resp.type = "result"
  resp.from = iq.to
  resp.to = iq.from
  resp.id = iq.id
  resp.lang = "en"
  items = resp.disco_items
  if disco_items.try &.node.try &.blank?
    items.add_item "service.localhost", "node1", "test node"
  end
  s.send resp
end

def version(s : XMPP::Sender, p : XMPP::Stanza::Packet)
  return unless p.is_a?(XMPP::Stanza::IQ)
  iq = p.as(XMPP::Stanza::IQ)
  resp = XMPP::Stanza::IQ.new
  resp.type = "result"
  resp.from = iq.to
  resp.to = iq.from
  resp.id = iq.id
  resp.lang = "en"

  resp.version.set_info("Crystal XMPP Component", "0.1.0", "")
  s.send resp
end
