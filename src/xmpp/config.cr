require "./jid"
require "./auth"

module XMPP
  struct Config
    getter jid : String
    getter password : String
    getter host : String
    getter port : Int32
    # True when the caller supplied an explicit host, in which case SRV-based
    # connection discovery is skipped.
    getter? host_explicit : Bool
    getter lang : String
    getter connect_timeout : Int32
    getter io_timeout : Int32
    getter max_stanza_size : Int32
    getter tls_ca_certificates : String?
    getter? tls : Bool # TLS Support
    # skip_cert_verify can be set to true to allow to open a TLS session and skip
    # verification of SSL certs
    getter? skip_cert_verify : Bool
    getter log_file : IO?
    getter parsed_jid : JID
    # Ordered SASL mechanisms offered to the selector. Defaults to the
    # SCRAM-only `SASL_AUTH_ORDER`. Pass `LEGACY_SASL_AUTH_ORDER` explicitly
    # when compatibility with PLAIN, DIGEST-MD5, or ANONYMOUS is required.
    getter sasl_auth_order : Array(AuthMechanism)
    # auto_presence controls whether to automatically send initial presence after connection
    # Set to false if you want to manually control presence (e.g., for invisible login)
    getter? auto_presence : Bool
    # prefer_direct_tls opts into XEP-0368 connection discovery: when true
    # and no explicit host is configured, the client looks up
    # _xmpps-client/_xmpp-client SRV records and connects using direct TLS
    # where the server offers it. Defaults to false (STARTTLS on port 5222).
    getter? prefer_direct_tls : Bool

    def initialize(@jid, @password, @host, @port = 5222, @lang = "en", @tls = true,
                   @skip_cert_verify = false, time_out = 15, @log_file = nil,
                   @sasl_auth_order = SASL_AUTH_ORDER, @auto_presence = true,
                   @io_timeout = 30, @max_stanza_size = XMLStreamReader::DEFAULT_MAX_ELEMENT_SIZE,
                   @tls_ca_certificates = nil, @prefer_direct_tls = false)
      raise ConfigurationError.new("missing password") if @password.blank?
      raise ConfigurationError.new("time_out must be positive") unless time_out > 0
      raise ConfigurationError.new("io_timeout must be positive") unless @io_timeout > 0
      raise ConfigurationError.new("max_stanza_size must be positive") unless @max_stanza_size > 0
      @connect_timeout = time_out
      @parsed_jid = JID.new @jid
      @host_explicit = !@host.blank?
      @host = @parsed_jid.domain if @host.blank?
    end
  end
end
