require "./jid"
require "./auth"

module XMPP
  struct Config
    getter jid : String
    getter password : String
    getter host : String
    getter port : Int32
    getter lang : String
    getter connect_timeout : Int32
    getter? tls : Bool # TLS Support
    # skip_cert_verify can be set to true to allow to open a TLS session and skip
    # verification of SSL certs
    getter? skip_cert_verify : Bool
    getter log_file : IO?
    getter parsed_jid : JID
    getter sasl_auth_order : Array(AuthMechanism)
    # auto_presence controls whether to automatically send initial presence after connection
    # Set to false if you want to manually control presence (e.g., for invisible login)
    getter? auto_presence : Bool

    def initialize(@jid, @password, @host, @port = 5222, @lang = "en", @tls = true,
                   @skip_cert_verify = true, time_out = 15, @log_file = nil,
                   @sasl_auth_order = SASL_AUTH_ORDER, @auto_presence = true)
      raise "missing password" if @password.blank?
      @connect_timeout = time_out
      @parsed_jid = JID.new @jid
      @host = @parsed_jid.domain if @host.blank?
    end
  end
end
