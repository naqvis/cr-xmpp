require "base64"

module XMPP
  private class AuthHandler
    # Plain authentication: send base64-encoded \x00 user \x00 password
    def auth_plain
      raw = "\x00#{@jid.node}\x00#{@password}"
      enc = Base64.encode(raw)
      send Stanza::SASLAuth.new(mechanism: "PLAIN", body: enc)
      handle_resp("plain")
    end
  end
end
