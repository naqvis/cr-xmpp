# Changelog

Notable project changes are recorded here. Usage belongs in
[`README.md`](README.md), while current protocol coverage and limitations
belong in [`PROTOCOL.md`](PROTOCOL.md).

## Unreleased

### Reliability

- Added explicit `Connecting` and `Disconnecting` states and a synchronized
  `current_state` API for clients and external components.
- Made client/component shutdown and `StreamManager#stop` idempotent.
- Removed competing socket readers during graceful shutdown.
- Scoped receiver and keepalive fibers to immutable per-connection state so
  stale fibers cannot access replacement connections.
- Serialized all stanza and keepalive writes across fibers.
- Made reconnection asynchronous and deduplicated concurrent reconnect
  requests; retry waits are now cancellable.
- Replaced fixed reconnect delays with configurable bounded exponential
  backoff and jitter, with permanent/transient failure classification.
- Added typed errors for duplicate connections, disconnected sends,
  stream-management saturation, and invalid acknowledgements.
- Added typed configuration, TLS negotiation/verification, authentication,
  stream parsing, stanza dispatch, and component-policy errors.
- Propagated unexpected disconnect causes through lifecycle events and manager
  metrics instead of reducing them to an unqualified disconnected state.
- Corrected XEP-0198 resumption accounting, including UInt32 wraparound and
  retaining resent stanzas until the server acknowledges them.
- Corrected XEP-0198 `<a/>` dispatch and sequence accounting for the
  synchronous discovery exchange performed after stream management starts.
- Enforced a 100-stanza stream-management queue boundary.
- Made unacknowledged-stanza inspection return a synchronized snapshot instead
  of exposing the mutable stream-management queue.
- Exposed thread-safe connection timing, retry, disconnect, stream-error,
  resumption, last-error, and live stream-management queue metrics.
- Fixed component delegation/privilege code paths that previously failed when
  compiling component applications.

### Features

- Implemented RFC 7590 anti-stripping STARTTLS, certificate/hostname
  verification, and `tls_version`/`cipher`/`tls_verified?` introspection.
- Implemented XEP-0368 SRV-based connection discovery with direct TLS
  preference via the `prefer_direct_tls` option and STARTTLS fallback.
- Added XEP-0163 personal eventing (PEP) with publish/subscribe/unsubscribe
  and incoming `Stanza::PubSubEvent` notification parsing.
- Added XEP-0352 client state indication via `XMPP::ClientStateIndication`.
- Added XEP-0357 push notification enable/disable and discovery via
  `XMPP::Push`.
- Implemented RFC 7395 XMPP over WebSocket and XEP-0206 XMPP over BOSH behind a
  common transport abstraction selected with `Config#transport`
  (`TransportMode::WebSocket` / `TransportMode::Bosh`), including WebSocket
  PING keepalives and BOSH session creation, stream restart, stanza flushing,
  and session termination.
- Implemented XEP-0156 alternative-connection discovery from the HTTPS
  host-meta document (XRD/JRD) and a `TransportMode::Auto` mode that tries the
  classic RFC 6120 TCP path first and then falls back to discovered
  WebSocket/BOSH endpoints.

### Security

- Replaced one-shot XML reads with a strict incremental stream reader that
  handles fragmentation/coalescing, preserves namespaces, rejects DTDs and
  malformed XML, and enforces a configurable element-size limit.
- Enabled certificate and hostname verification by default and disabled TLS
  1.0/1.1.
- Added configurable connect/I/O timeouts and private CA bundles.
- Hardened SCRAM with secure nonces, strict challenge parsing, bounded
  iteration counts, SASL preparation, constant-time comparisons, and mandatory
  server-final verification.
- Implemented `tls-exporter`, `tls-server-end-point`, and `tls-unique`.
- Implemented XEP-0474 and XEP-0515 downgrade protection.
- Restricted the default SASL policy to SCRAM/SCRAM-PLUS. Legacy mechanisms
  now require explicit opt-in, and `PLAIN` requires certificate-verified TLS.

### Tooling and validation

- Added `scripts/ci` as the shared local and hosted release gate.
- Added certificate-verified live interoperability coverage against a
  digest-pinned Prosody 13 image.
- Added live abrupt-transport XEP-0198 resumption and real XEP-0114 component
  authentication/failure coverage.
- Added live WebSocket (RFC 7395) and BOSH (XEP-0206) round-trip coverage
  against Prosody alongside the existing TLS/SASL interoperability tests.
- Consolidated development and integration onto one canonical
  `docker-compose.yml`; integration runs under an isolated Compose project and
  volume.
- Run unit and live coverage with four Crystal execution workers.
- Made repository-root discovery independent of the caller’s `CDPATH`.
- Added buffering regressions for large fragmented elements and thousands of
  coalesced stanzas, and removed obsolete lifecycle helpers.

### Documentation

- Separated usage, protocol coverage, and project history across README,
  PROTOCOL, and CHANGELOG without duplicating the support matrix.
- Re-audited the source registry and restored previously omitted stanza/API
  support, with explicit integrated/API/partial status instead of overstating
  every XEP as complete.
- Documented the secure SASL defaults and legacy compatibility opt-in.
- Documented lifecycle states, concurrency guarantees, typed errors, local
  validation, and custom CA configuration.
- Documented WebSocket (RFC 7395), BOSH (XEP-0206), and alternative-connection
  discovery (XEP-0156) in the protocol support matrix and DOAP file.

## Earlier development history

The following capabilities were added before the current hardening work. This
section intentionally records outcomes rather than duplicating usage or
protocol documentation.

### Authentication and channel binding

- Added SASL2 (XEP-0388), SASL upgrade tasks (XEP-0480), SCRAM-PLUS, and TLS
  channel-binding support.
- Added XEP-0440 capability negotiation and XEP-0474 downgrade-protection
  structures.

### Stream management

- Added XEP-0198 state persistence, outbound stanza tracking,
  acknowledgement processing, session resumption, and automatic resend.

### Components

- Added XEP-0030 discovery for external components.
- Added component-side XEP-0355 namespace delegation and XEP-0356 privileged
  entity support.

### Messaging and PubSub

- Added subscriber-side XEP-0060 operations for subscriptions, affiliations,
  item retrieval, publishing, and retraction.
- Added XEP-0107 mood parsing and configurable automatic initial presence.
