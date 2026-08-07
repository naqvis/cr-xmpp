# Crystal XMPP

![CI](https://github.com/naqvis/cr-xmpp/workflows/CI/badge.svg)
[![GitHub release](https://img.shields.io/github/release/naqvis/cr-xmpp.svg)](https://github.com/naqvis/cr-xmpp/releases)
[![API docs](https://img.shields.io/badge/docs-API-brightgreen.svg)](https://naqvis.github.io/cr-xmpp/)

`cr-xmpp` is a pure-Crystal, event-driven toolkit for building XMPP clients,
bots, automation services, connected devices, gateways, and XEP-0114 external
components. It manages the wire protocol and connection lifecycle while
exposing XMPP through typed, extensible Crystal APIs.

Highlights include:

- Secure client sessions with verified STARTTLS, SASL1 and SASL2,
  SCRAM-SHA-1/256/512 and their `-PLUS` variants, TLS channel binding, and
  authentication downgrade protection.
- Resilient long-running connections with supervised reconnection,
  XEP-0198 stream resumption, acknowledgement tracking, bounded resend queues,
  serialized concurrent writes, timeouts, and explicit lifecycle errors.
- Event-based routing for messages, presence, and IQ stanzas, backed by
  typed parsing and serialization for common messaging, discovery, PubSub/PEP,
  MUC, forwarding, IoT, and metadata extensions.
- External-component support with service discovery, namespace delegation,
  privileged-entity helpers, and the same routing and lifecycle model used by
  clients.
- Multiple connection transports: classic RFC 6120 TCP (STARTTLS or XEP-0368
  direct TLS), RFC 7395 WebSocket, XEP-0206 BOSH, and XEP-0156 auto-discovery
  of alternative endpoints.
- An extension registry and generic XML-node fallback for adding custom or
  experimental protocols without forking the shard.

See the [protocol support matrix](PROTOCOL.md) for the exact integrated,
API-level, and partial scope of each specification.

## Documentation

- [Protocol support](PROTOCOL.md) — implemented, partial, and missing RFCs/XEPs
- [Changelog](CHANGELOG.md) — release and development history
- [API documentation](https://naqvis.github.io/cr-xmpp/) — generated types and methods
- [Local Prosody environment](docker/README.md) — Docker setup and troubleshooting
- [Examples](examples/) — clients, components, PubSub, SASL, and channel binding

## Installation

Add the shard to `shard.yml`:

```yaml
dependencies:
  cr-xmpp:
    github: naqvis/cr-xmpp
```

Then install dependencies:

```bash
shards install
```

## Client quick start

```crystal
require "cr-xmpp"

config = XMPP::Config.new(
  host: "xmpp.example.com",
  jid: "bot@example.com/worker",
  password: ENV["XMPP_PASSWORD"],
  tls: true
)

router = XMPP::Router.new

router.message do |sender, packet|
  next unless message = packet.as?(XMPP::Stanza::Message)

  reply = XMPP::Stanza::Message.new
  reply.to = message.from
  reply.body = "Received: #{message.body}"
  sender.send(reply)
end

client = XMPP::Client.new(config, router)
manager = XMPP::StreamManager.new(client)
manager.run
```

`StreamManager` supervises the connection and reconnects unexpected
disconnections. Call `manager.stop` for graceful shutdown. Applications that
need direct lifecycle control can use `client.connect`, `client.send`, and
`client.disconnect`.

Reconnects use bounded exponential backoff with jitter. The defaults start at
one second and cap at 30 seconds; applications can tune them:

```crystal
policy = XMPP::ReconnectPolicy.new(
  initial_delay: 500.milliseconds,
  max_delay: 20.seconds,
  multiplier: 2.0,
  jitter: 0.2
)

manager = XMPP::StreamManager.new(
  client,
  retry_count: 8,
  reconnect_policy: policy
)
```

Authentication, certificate-verification, configuration, and malformed
protocol failures are classified as permanent and are not retried. Transport
and TLS-negotiation failures remain retryable.

## Configuration and security

TLS is enabled by default. The client verifies the certificate against the JID
domain, rejects TLS 1.0/1.1, applies socket I/O timeouts, and limits individual
XML elements to 1 MiB. Per RFC 7590 the client attempts STARTTLS even when the
server fails to advertise it, so a downgrade attack cannot silently strip
encryption.

The negotiated connection can be inspected with `client.tls_version`,
`client.cipher`, and `client.tls_verified?` (all `nil`/`false` when the stream
is not encrypted).

```crystal
config = XMPP::Config.new(
  host: "xmpp.example.com",
  port: 5222,
  jid: "bot@example.com/worker",
  password: ENV["XMPP_PASSWORD"],
  io_timeout: 20,
  max_stanza_size: 512 * 1024,
  tls_ca_certificates: "/etc/company/xmpp-ca.pem",
  auto_presence: false
)
```

### Direct TLS (XEP-0368)

Setting `prefer_direct_tls: true` opts into XEP-0368 connection discovery:
when no explicit `host` is configured, the client resolves `_xmpps-client` and
`_xmpp-client` SRV records and connects with TLS established immediately
(direct TLS) wherever the server offers it, falling back to STARTTLS. The
flag defaults to `false`, so existing configurations behave exactly as before.

```crystal
config = XMPP::Config.new(
  jid: "bot@example.com/worker",
  password: ENV["XMPP_PASSWORD"],
  prefer_direct_tls: true
)
```

`skip_cert_verify: true` disables certificate authentication and is intended
only for controlled development environments.

### WebSocket, BOSH, and auto-discovery

The same client can run over RFC 7395 WebSocket or XEP-0206 BOSH instead of a
classic TCP stream:

```crystal
config = XMPP::Config.new(
  jid: "bot@example.com/worker",
  password: ENV["XMPP_PASSWORD"],
  transport: XMPP::TransportMode::WebSocket, # or ::Bosh
  url: "wss://xmpp.example.com/ws"
)
```

`url` is optional: when omitted the client derives a default endpoint for the
selected transport (`wss://<domain>/ws` for WebSocket,
`https://<domain>:5280/http-bind` for BOSH). With
`transport: XMPP::TransportMode::Auto` the client tries the classic TCP
path first, then discovers WebSocket and BOSH endpoints from the server's
XEP-0156 HTTPS host-meta document and connects through the first one that
works. TLS verification, SASL, stream management, and routing behave
identically across all transports; SCRAM-PLUS channel binding is limited to
TCP (and direct TLS), where the TLS session is directly exposed.

### SASL policy

The default `XMPP::SASL_AUTH_ORDER` permits SCRAM and SCRAM-PLUS only. It does
not silently fall back to `PLAIN`, `DIGEST-MD5`, or `ANONYMOUS`.

Legacy interoperability must be enabled explicitly:

```crystal
sasl_auth_order: XMPP::LEGACY_SASL_AUTH_ORDER
```

Alternatively, select only the mechanisms required by the deployment:

```crystal
sasl_auth_order: [
  XMPP::AuthMechanism::SCRAM_SHA_256,
  XMPP::AuthMechanism::PLAIN,
]
```

`PLAIN` is accepted only over certificate-verified TLS. Disabling certificate
verification does not satisfy that requirement.

### Channel binding

SCRAM-PLUS is selected automatically when the server and TLS connection
support it. The library implements:

- `tls-exporter` for TLS 1.3
- `tls-server-end-point` for TLS 1.2 and TLS 1.3
- `tls-unique` for TLS 1.2 and earlier
- XEP-0474 SCRAM downgrade protection
- XEP-0515 TLS-version downgrade protection

See [the channel-binding example](examples/xmpp_channel_binding.cr).

### Personal Eventing (XEP-0163)

`XMPP::PEP` publishes items to the client's own nodes and subscribes to other
contacts' nodes:

```crystal
pep = XMPP::PEP.new(client)
pep.supported? # => true when the server advertises pubsub#pep

tune = XMPP::Stanza::Tune.new
tune.artist = "The Beatles"
tune.title = "Hey Jude"

item = XMPP::Stanza::Item.new
item.tune = tune
pep.publish "http://jabber.org/protocol/tune", item
pep.subscribe "friend@example.org", "http://jabber.org/protocol/tune"
```

Incoming PEP notifications arrive as `XMPP::Stanza::PubSubEvent` message
payloads:

```crystal
client.on("message") do |s, p|
  message = p.as(XMPP::Stanza::Message)
  if event = message.get(XMPP::Stanza::PubSubEvent)
    event.items.not_nil!.node          # => "http://jabber.org/protocol/tune"
    event.items.not_nil!.items         # => published items
  end
end
```

## High-level helpers

Beyond PEP, the library ships typed clients for common server-side features.
Each takes an `XMPP::Client` and performs the full stanza exchange:

- `XMPP::VCard` — XEP-0054 vCard fetch/set on the bare JID.
- `XMPP::PrivateXmlStorage` — XEP-0049 `jabber:iq:private` retrieve/store.
- `XMPP::Blocking` — XEP-0191 blocklist management (`block`, `unblock`,
  `list`, `supported?`).
- `XMPP::Carbons` — XEP-0280 message carbons enable/disable and forwarding.
- `XMPP::Me` / `XMPP::DirectInvitation` — XEP-0245 `/me` and XEP-0249 direct
  MUC invites.
- `XMPP::HTTPUpload` — XEP-0363 slot request plus HTTPS PUT upload.
- `XMPP::Bookmarks` / `XMPP::UserAvatar` — XEP-0048/0402 bookmarks and
  XEP-0084/0398 avatars over PEP.
- `XMPP::MessageCorrection` — XEP-0308 last-message correction.
- `XMPP::MessageArchives` — XEP-0313 MAM queries with RSM paging and
  `with`/`since`/`until` filters.
- `XMPP::Jingle` — XEP-0234/0261 file-transfer and in-band-bytestream
  offer/accept construction.

```crystal
vcard = XMPP::VCard.new(client)
card = vcard.fetch                       # => Stanza::VCard? for the bare JID
card.fn = "Juliet Capulet"
vcard.set(card)

archives = XMPP::MessageArchives.new(client)
archives.query(with_jid: "romeo@montague.lit", limit: 10)   # => Stanza::MAMFin?
```

Incoming `Stanza::MAMResult` messages carry each archived item as a forwarded
message. See [PROTOCOL.md](PROTOCOL.md) for the exact scope of each feature.

## Lifecycle and concurrency

`current_state` reports:

- `Disconnected`
- `Connecting`
- `Connected`
- `SessionEstablished`
- `Disconnecting`
- `StreamError`

Connection shutdown and manager stop are idempotent. Writes from multiple
fibers are serialized so XML fragments cannot interleave.

Unexpected disconnect events include the originating exception and description.
`StreamManager#metrics` exposes connection/login timing, connection and
reconnect attempts, failures, disconnects, stream errors, XEP-0198 resumption
outcomes, the last error, and current unacknowledged-stanza queue depth.

When XEP-0198 is active, the client retains at most 100 unacknowledged stanzas.
Reaching that boundary raises `XMPP::SendQueueFullError`. Sending while
disconnected raises `XMPP::NotConnectedError`, and starting a duplicate
connection raises `XMPP::AlreadyConnectedError`. These inherit from
`XMPP::ConnectionError`.

## External components

External components use the same router and supervised lifecycle:

```crystal
options = XMPP::ComponentOptions.new(
  domain: "gateway.example.com",
  secret: ENV["XMPP_COMPONENT_SECRET"],
  host: "xmpp.example.com",
  port: 5347,
  name: "Example gateway",
  category: "gateway",
  type: "generic"
)

component = XMPP::Component.new(options, XMPP::Router.new)
XMPP::StreamManager.new(component).run
```

See the [component examples](examples/) for service discovery, namespace
delegation, and privileged-entity usage. Exact protocol coverage and
limitations belong in [PROTOCOL.md](PROTOCOL.md).

## Development and testing

Run the same release gate locally that the hosted workflow uses:

```bash
./scripts/ci unit
./scripts/ci integration
./scripts/ci all
```

The unit gate checks dependencies, formatting, specs under default and
four-worker execution, and API documentation. The integration gate generates a
temporary CA, starts digest-pinned Prosody from the canonical
`docker-compose.yml`, runs live TLS/SASL/concurrency tests, and removes its
isolated container and volume.

For manual server operation and user-management commands, see
[docker/README.md](docker/README.md).

## Extending stanzas

XMPP extensions are represented by types under `XMPP::Stanza`. Custom
extensions implement the appropriate payload module, provide XML parsing and
serialization, and register their XML name with the stanza registry. Existing
implementations under [`src/xmpp/stanza`](src/xmpp/stanza/) are the canonical
examples.

## Contributing

1. Fork the repository.
2. Create a focused branch.
3. Add or update specs for the change.
4. Run `./scripts/ci all`.
5. Open a pull request.

## License

`cr-xmpp` is distributed under the [MIT License](LICENSE).

## Contributors

- [Ali Naqvi](https://github.com/naqvis) — creator and maintainer
