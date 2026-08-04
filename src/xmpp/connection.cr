require "./config"
require "./dns_srv"

module XMPP
  # How the client should negotiate security on the transport.
  enum ConnectionMode
    # Classic STARTTLS upgrade on an unencrypted stream (RFC 6120 / RFC 7590).
    StartTls
    # XEP-0368 direct TLS: TLS is established immediately on connect, before
    # any XMPP stream bytes are sent.
    DirectTls
  end

  # A resolved endpoint ready to connect to.
  record ResolvedEndpoint, host : String, port : Int32, mode : ConnectionMode

  # Resolves how and where a client should connect, combining explicit
  # configuration with optional XEP-0368 SRV discovery.
  module ConnectionResolver
    # Returns the ordered list of endpoints to try.
    #
    # When the caller pinned an explicit host, or direct-TLS discovery is not
    # requested, the sole endpoint is the configured host/port in STARTTLS
    # mode (the original behavior).
    #
    # When prefer_direct_tls is enabled and no host was pinned, both
    # _xmpps-client and _xmpp-client SRV records are looked up and merged per
    # XEP-0368 §3, preferring direct-TLS targets first. If discovery returns
    # nothing, the client falls back to the configured host/port with
    # STARTTLS (matching a "." target or absent records).
    def self.resolve(config : Config) : Array(ResolvedEndpoint)
      if config.host_explicit? || !config.prefer_direct_tls?
        return [ResolvedEndpoint.new(config.host, config.port, ConnectionMode::StartTls)]
      end

      domain = config.parsed_jid.domain

      direct = DnsSrv.resolve("_xmpps-client", domain)
      starttls = DnsSrv.resolve("_xmpp-client", domain)

      endpoints = [] of ResolvedEndpoint
      direct.each do |record|
        next if record.target == "."
        endpoints << ResolvedEndpoint.new(record.target, record.port.to_i32, ConnectionMode::DirectTls)
      end
      starttls.each do |record|
        next if record.target == "."
        endpoints << ResolvedEndpoint.new(record.target, record.port.to_i32, ConnectionMode::StartTls)
      end

      unless endpoints.empty?
        return endpoints
      end

      # No SRV records; fall back to the configured (JID-derived) host.
      [ResolvedEndpoint.new(config.host, config.port, ConnectionMode::StartTls)]
    end
  end
end
