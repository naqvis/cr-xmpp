# Protocol support

This file is the protocol inventory for `cr-xmpp`. It distinguishes integrated library behavior from stanza/data-model support so that “supported” does not overstate what the shard does automatically.

## Status definitions

- **Integrated** — used directly by the client, session, authentication, stream-management, router, or component workflow.
- **API** — typed parsing/serialization is available, but applications must drive the protocol workflow.
- **Partial** — only the stated subset is implemented.

## RFC support

| Standard                                  | Status     | Scope                                                                                                                |
| ----------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------- |
| RFC 6120 — XMPP Core                      | Integrated | Client streams, STARTTLS, SASL, resource binding, stanzas, stream errors                                             |
| RFC 6121 — Instant Messaging and Presence | Integrated | Message/presence routing and roster payloads                                                                         |
| RFC 7590 — Use of TLS in XMPP             | Integrated | Anti-stripping STARTTLS, certificate/hostname verification, and `tls_version`/`cipher`/`tls_verified?` introspection |
| RFC 7395 — XMPP over WebSocket            | Integrated | RFC 7395 framing over `HTTP::WebSocket` (`<open/>`/`<close/>` translation) and WebSocket PING keepalive                                       |
| RFC 5802 — SCRAM-SHA-1                    | Integrated | SCRAM exchange, server verification, and channel binding                                                             |
| RFC 7677 — SCRAM-SHA-256                  | Integrated | SCRAM-SHA-256 and SCRAM-SHA-256-PLUS                                                                                 |
| RFC 4013 — SASLprep                       | Partial    | NFKC normalization and prohibited-character checks used by SCRAM                                                     |
| RFC 4505 — SASL ANONYMOUS                 | Optional   | Available only through explicit legacy mechanism policy                                                              |
| RFC 4616 — SASL PLAIN                     | Optional   | Available only through explicit policy and certificate-verified TLS                                                  |
| RFC 2831 — DIGEST-MD5                     | Legacy     | Available only through explicit legacy mechanism policy                                                              |
| RFC 5929 — TLS Channel Bindings           | Integrated | `tls-unique` and `tls-server-end-point`                                                                              |
| RFC 9266 — Channel Bindings for TLS 1.3   | Integrated | `tls-exporter`                                                                                                       |

## XEP support

| XEP                                                 | Status     | Implemented scope                                                                                                               |
| --------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------- |
| XEP-0030 — Service Discovery                        | Integrated | Client disco query plus component info/items responders and nodes                                                               |
| XEP-0045 — Multi-User Chat                          | Partial    | MUC presence and history payloads; no room administration/configuration                                                         |
| XEP-0060 — Publish-Subscribe                        | API        | Publish, retract, subscribe, unsubscribe, subscriptions, affiliations, and item retrieval                                       |
| XEP-0066 — Out of Band Data                         | API        | Message payload parsing and serialization                                                                                       |
| XEP-0071 — XHTML-IM                                 | API        | XHTML message body parsing and serialization                                                                                    |
| XEP-0085 — Chat State Notifications                 | API        | Active, composing, paused, inactive, and gone markers                                                                           |
| XEP-0092 — Software Version                         | API        | IQ request/result payload                                                                                                       |
| XEP-0107 — User Mood                                | API        | Mood values, validation, text, parsing, and serialization                                                                       |
| XEP-0114 — Jabber Component Protocol                | Integrated | External-component connect/authenticate/send/receive; no component dialback                                                     |
| XEP-0115 — Entity Capabilities                      | Partial    | Presence capability payload parsing/serialization; no verification cache                                                        |
| XEP-0118 — User Tune                                | API        | Tune data model for PubSub/PEP payloads                                                                                         |
| XEP-0163 — Personal Eventing Protocol               | Integrated | PEP publish/subscribe/unsubscribe, event notification parsing (`Stanza::PubSubEvent`), and disco-based support detection        |
| XEP-0153 — vCard-Based Avatars                      | API        | Presence update payload                                                                                                         |
| XEP-0156 — Discovering Alternative Connection Methods | Integrated | HTTPS host-meta (XRD/JRD) discovery of WebSocket and BOSH endpoints; DNS TXT method intentionally omitted (removed from the spec)              |
| XEP-0184 — Message Delivery Receipts                | API        | Receipt request and received markers                                                                                            |
| XEP-0198 — Stream Management                        | Integrated | Enable/resume, bounded outbound tracking, acknowledgements, resend, and live cut/resume interoperability coverage               |
| XEP-0199 — XMPP Ping                                | Integrated | Ping payload, automatic replies, and keepalive use                                                                              |
| XEP-0206 — XMPP over BOSH                    | Integrated | Long-poll transport, session creation, stream restart, stanza flush, and terminate                                                             |
| XEP-0203 — Delayed Delivery                         | API        | Message and presence delay payloads                                                                                             |
| XEP-0297 — Stanza Forwarding                        | API        | Forwarded wrapper parsing/serialization                                                                                         |
| XEP-0325 — IoT Control                              | Partial    | Control `set`, fields, `getForm`, and `setResponse` data models                                                                 |
| XEP-0333 — Chat Markers                             | API        | Markable, received, displayed, and acknowledged markers                                                                         |
| XEP-0334 — Message Processing Hints                 | API       | Store, no-store, no-permanent-store, and no-copy hints                                                                          |
| XEP-0352 — Client State Indication                 | API       | `Stanza::CSIActive`/`Stanza::CSIInactive` nonza sends via `XMPP::ClientStateIndication` |
| XEP-0355 — Namespace Delegation                     | Partial    | Component-side advertisements, delegated IQ unwrapping, and response wrapping                                                   |
| XEP-0356 — Privileged Entity                        | Partial    | Component-side permissions, roster helpers, and outgoing privileged messages                                                    |
| XEP-0357 — Push Notifications                      | API       | client-side enable/disable and `urn:xmpp:push:0` discovery via `XMPP::Push` |
| XEP-0368 — SRV records for XMPP over TLS            | Integrated | `_xmpps-client`/`_xmpp-client` discovery, direct TLS connection, and STARTTLS fallback via the `prefer_direct_tls` option       |
| XEP-0380 — Explicit Message Encryption              | API        | Encryption marker and encryption-namespace identifiers; no encryption engine                                                    |
| XEP-0386 — Bind 2                                   | Integrated | SASL2 inline discovery, bind requests, bound-result handling, assigned-JID propagation, and extensible session feature payloads |
| XEP-0388 — Extensible SASL Profile (SASL2)          | Integrated | Feature parsing and authentication flow with classic SASL fallback                                                              |
| XEP-0440 — SASL Channel-Binding Type Capability     | Integrated | Capability parsing, selection, and SCRAM-PLUS negotiation                                                                       |
| XEP-0453 — DOAP usage in XMPP                       | API        | RDF/XML project parsing/serialization, common DOAP properties, repositories, releases, and typed `SupportedXep` records         |
| XEP-0474 — SASL SCRAM Downgrade Protection          | Integrated | Signed mechanism/channel-binding downgrade verification                                                                         |
| XEP-0480 — SASL Upgrade Tasks                       | Integrated | SCRAM upgrade advertisement, task exchange, and hash generation                                                                 |
| XEP-0515 — TLS Channel-Binding Downgrade Protection | Integrated | Negotiated TLS-version verification in SCRAM                                                                                    |

## Non-standard extensions

- ejabberd `p1:ack`, `p1:push`, and `p1:rebind` stream-feature models.
- Generic unknown XML payload preservation through `XMPP::Stanza::Node`.

## Not implemented

The presence of a generic PubSub, forwarding, or encryption-marker model does not imply these separate protocols are implemented:

- XEP-0084: User Avatar
- XEP-0191: Blocking Command
- XEP-0280: Message Carbons
- XEP-0308: Last Message Correction
- XEP-0313: Message Archive Management
- XEP-0359: Unique and Stable Stanza IDs
- XEP-0363: HTTP File Upload
- XEP-0384: OMEMO Encryption
- XEP-0424: Message Retraction
- XEP-0444: Message Reactions
- XEP-0461: Message Replies
