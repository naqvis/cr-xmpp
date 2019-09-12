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
    getter tls : Bool # TLS Support
    # skip_cert_verify can be set to true to allow to open a TLS session and skip
    # verification of SSL certs
    getter skip_cert_verify : Bool
    getter log_file : IO?
    getter parsed_jid : JID
    getter sasl_auth_order : Array(AuthMechanism)

    def initialize(@jid, @password, @host, @port = 5222, @lang = "en", @tls = true,
                   @skip_cert_verify = true, time_out = 15, @log_file = nil,
                   @sasl_auth_order = SASL_AUTH_ORDER)
      raise "missing password" if @password.blank?
      @connect_timeout = time_out
      @parsed_jid = JID.new @jid
      @host = @parsed_jid.domain if @host.blank?
    end
  end
end
