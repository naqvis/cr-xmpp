require "./jid"

module XMPP
  struct Config
    getter jid : String
    getter password : String
    getter host : String
    getter port : Int32
    getter lang : String
    getter connect_timeout : Int32
    getter tls : Bool # TLS Support
    # allow_insecure can be set to true to allow to open a session without TLS. If TLS
    # is supported on the server, we will still try to use it.
    getter allow_insecure : Bool
    getter log_file : IO?
    getter parsed_jid : JID

    def initialize(@jid, @password, @host, @port = 5222, @lang = "en", @tls = false,
                   @allow_insecure = true, time_out = 15, @log_file = nil)
      raise "missing password" if @password.blank?
      @connect_timeout = time_out
      @parsed_jid = JID.new @jid
      @host = @parsed_jid.domain if @host.blank?
    end
  end
end
