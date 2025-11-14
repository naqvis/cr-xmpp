# Crystal XMPP Library
#
# A pure Crystal implementation of XMPP (Jabber) protocol with support for:
# - RFC 6120: XMPP Core
# - RFC 6121: XMPP Instant Messaging and Presence
# - Multiple XEPs (XMPP Extension Protocols)
# - Channel Binding for TLS (RFC 5929, RFC 9266)
# - SCRAM-PLUS authentication mechanisms
# - XEP-0388: Extensible SASL Profile
# - XEP-0440: SASL Channel-Binding Type Capability
# - XEP-0474: SASL SCRAM Downgrade Protection
#
# Channel Binding Support:
# This library implements channel binding for enhanced security, which
# cryptographically binds SASL authentication to the TLS connection,
# preventing man-in-the-middle attacks.
#
# Supported channel binding types:
# - tls-server-end-point (RFC 5929) - Fully implemented
# - tls-unique (RFC 5929) - For TLS ≤ 1.2 (requires OpenSSL FFI)
# - tls-exporter (RFC 9266) - For TLS 1.3 (requires OpenSSL FFI)
#
# SCRAM-PLUS mechanisms (with channel binding):
# - SCRAM-SHA-512-PLUS (recommended)
# - SCRAM-SHA-256-PLUS
# - SCRAM-SHA-1-PLUS
#
# These are automatically preferred when TLS is enabled and the server
# advertises support for them.

module XMPP
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
end

require "./xmpp"
