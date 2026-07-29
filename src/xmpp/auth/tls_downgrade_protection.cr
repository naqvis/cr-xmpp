module XMPP
  # XEP-0515: TLS Channel-Binding Downgrade Protection
  #
  # The server's `t` attribute is part of the signed SCRAM
  # server-first-message. Comparing it with the locally negotiated TLS version
  # prevents a MITM from using different TLS versions on each side in order to
  # downgrade the available channel-binding types.
  module TLSChannelBindingDowngradeProtection
    TLS_VERSION_CODES = {
      "TLSv1.3" => "0304",
      "TLSv1.2" => "0303",
      "TLSv1.1" => "0302",
      "TLSv1"   => "0301",
      "TLSv1.0" => "0301",
    }

    # Returns the four lower-case hexadecimal characters assigned to a TLS
    # protocol version by the TLS specifications.
    def self.version_code(tls_version : String) : String?
      TLS_VERSION_CODES[tls_version]?
    end

    # Verifies the optional XEP-0515 SCRAM attribute.
    #
    # A missing `t` attribute means that the server does not implement
    # XEP-0515. If an implementing server's attribute were removed in transit,
    # the SCRAM proof would still fail because the original server-first-message
    # is included in SCRAM's AuthMessage.
    def self.verify!(server_version : String?, negotiated_tls_version : String?) : Nil
      return unless server_version

      unless negotiated_tls_version
        raise AuthenticationError.new(
          "Server sent XEP-0515 TLS version '#{server_version}', but no TLS connection is available"
        )
      end

      expected = version_code(negotiated_tls_version)
      unless expected
        raise AuthenticationError.new(
          "Cannot verify XEP-0515 for unsupported negotiated TLS version '#{negotiated_tls_version}'"
        )
      end

      return if server_version == expected

      raise AuthenticationError.new(
        "TLS version mismatch detected by XEP-0515: server reported '#{server_version}', " \
        "local connection uses '#{expected}' (#{negotiated_tls_version})"
      )
    end
  end
end
