module XMPP
  private class AuthHandler
    # Anonymous Auth
    def auth_anonymous
      send Stanza::SASLAuth.new(mechanism: "ANONYMOUS")
      handle_resp("anonymous")
    end
  end
end
