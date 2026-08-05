require "openssl"
require "./config"

module XMPP
  # Shared TLS helpers used by both STARTTLS upgrades and XEP-0368 direct
  # TLS connections so certificate handling stays consistent.
  module TLSConnection
    # Builds the client TLS context (CA bundle, TLS version policy,
    # verification policy) used by STARTTLS/direct-TLS sockets, WebSocket
    # (wss), and BOSH (https) alike so certificate handling stays consistent.
    def self.client_context(config : Config) : OpenSSL::SSL::Context::Client
      context = OpenSSL::SSL::Context::Client.new
      context.add_options(
        OpenSSL::SSL::Options::NO_TLS_V1 |
        OpenSSL::SSL::Options::NO_TLS_V1_1
      )
      if ca_certificates = config.tls_ca_certificates
        context.ca_certificates = ca_certificates
      end
      if config.skip_cert_verify?
        Logger.warn "TLS certificate verification is disabled; this connection is vulnerable to impersonation"
        context.verify_mode = OpenSSL::SSL::VerifyMode::None
      end
      context
    end

    # Wraps an already-connected socket in a client TLS socket, applying the
    # configured CA bundle and certificate verification policy. On failure the
    # underlying socket is closed so the caller can try the next endpoint.
    def self.wrap(socket : IO, config : Config, hostname : String) : OpenSSL::SSL::Socket::Client
      context = client_context(config)
      begin
        host = config.skip_cert_verify? ? nil : hostname
        tls_conn = OpenSSL::SSL::Socket::Client.new(socket, context, hostname: host)
        tls_conn.sync = true
        tls_conn
      rescue ex : OpenSSL::SSL::Error
        # don't leak the TCP socket when the SSL connection failed
        socket.close
        message = ex.message || "TLS handshake failed"
        if !config.skip_cert_verify? && verification_failure?(message)
          raise TLSVerificationError.new("TLS certificate or hostname verification failed: #{message}")
        end
        raise TLSNegotiationError.new("TLS handshake failed: #{message}")
      rescue ex
        socket.close
        raise ex
      end
    end

    # Best-effort detection of certificate/hostname verification failures from
    # OpenSSL error messages, which vary across platforms and versions.
    def self.verification_failure?(message : String) : Bool
      normalized = message.downcase
      normalized.includes?("certificate verify") ||
        normalized.includes?("hostname") ||
        normalized.includes?("does not match")
    end
  end
end
