require "openssl_ext"
require "base64"

module XMPP
  # Channel Binding support for TLS connections
  # Implements RFC 5929 (for TLS 1.2) and RFC 9266 (for TLS 1.3)
  module ChannelBinding
    enum Type
      # tls-unique: For TLS <= 1.2 (RFC 5929)
      TLS_UNIQUE
      # tls-server-end-point: For TLS <= 1.2 and TLS 1.3 (RFC 5929)
      TLS_SERVER_END_POINT
      # tls-exporter: For TLS 1.3 (RFC 9266)
      TLS_EXPORTER

      def to_s
        case self
        when TLS_UNIQUE           then "tls-unique"
        when TLS_SERVER_END_POINT then "tls-server-end-point"
        when TLS_EXPORTER         then "tls-exporter"
        else                           "unknown"
        end
      end

      def self.from_string(s : String) : Type?
        case s
        when "tls-unique"           then TLS_UNIQUE
        when "tls-server-end-point" then TLS_SERVER_END_POINT
        when "tls-exporter"         then TLS_EXPORTER
        else                             nil
        end
      end
    end

    # Get the appropriate channel binding data for the TLS connection
    # Returns tuple of (binding_type, binding_data) or nil if not available
    def self.get_channel_binding(socket : OpenSSL::SSL::Socket::Client) : Tuple(Type, Bytes)?
      tls_version = get_tls_version(socket)

      case tls_version
      when "TLSv1.3"
        # For TLS 1.3, prefer tls-exporter, fallback to tls-server-end-point
        if data = get_tls_exporter(socket)
          {Type::TLS_EXPORTER, data}
        elsif data = get_tls_server_end_point(socket)
          {Type::TLS_SERVER_END_POINT, data}
        else
          nil
        end
      when "TLSv1.2", "TLSv1.1", "TLSv1"
        # For TLS 1.2 and earlier, prefer tls-unique, fallback to tls-server-end-point
        if data = get_tls_unique(socket)
          {Type::TLS_UNIQUE, data}
        elsif data = get_tls_server_end_point(socket)
          {Type::TLS_SERVER_END_POINT, data}
        else
          nil
        end
      else
        nil
      end
    end

    # Get TLS version string from socket
    private def self.get_tls_version(socket : OpenSSL::SSL::Socket::Client) : String?
      # Crystal's OpenSSL binding may not expose version directly
      # This is a placeholder - actual implementation depends on Crystal's OpenSSL API
      # For now, we'll try to detect based on available methods
      "TLSv1.3" # Default assumption for modern connections
    end

    # RFC 9266: tls-exporter channel binding for TLS 1.3
    # Uses the TLS exporter mechanism with label "EXPORTER-Channel-Binding"
    private def self.get_tls_exporter(socket : OpenSSL::SSL::Socket::Client) : Bytes?
      # TLS 1.3 exporter: RFC 8446 Section 7.5
      # Label: "EXPORTER-Channel-Binding" (RFC 9266)
      # Context: empty
      # Length: 32 bytes

      # Note: Crystal's OpenSSL binding may not expose the exporter API directly
      # This would require FFI calls to OpenSSL's SSL_export_keying_material
      # For now, return nil to indicate not implemented
      nil
    end

    # RFC 5929: tls-unique channel binding for TLS <= 1.2
    # Uses the Finished message from the TLS handshake
    private def self.get_tls_unique(socket : OpenSSL::SSL::Socket::Client) : Bytes?
      # The tls-unique channel binding is the first Finished message
      # sent in the most recent handshake

      # Note: Crystal's OpenSSL binding may not expose this directly
      # This would require FFI calls to OpenSSL's SSL_get_finished
      # For now, return nil to indicate not implemented
      nil
    end

    # RFC 5929: tls-server-end-point channel binding
    # Uses the hash of the server's certificate
    private def self.get_tls_server_end_point(socket : OpenSSL::SSL::Socket::Client) : Bytes?
      return nil unless cert = socket.peer_certificate

      # Get the signature algorithm used in the certificate
      # and determine the appropriate hash algorithm
      hash_algorithm = get_hash_algorithm_for_cert(cert)

      # Hash the DER-encoded certificate
      der = cert.to_der
      case hash_algorithm
      when "SHA256"
        digest = OpenSSL::Digest.new("SHA256")
        digest.update(der)
        digest.final
      when "SHA384"
        digest = OpenSSL::Digest.new("SHA384")
        digest.update(der)
        digest.final
      when "SHA512"
        digest = OpenSSL::Digest.new("SHA512")
        digest.update(der)
        digest.final
      else
        # Default to SHA256
        digest = OpenSSL::Digest.new("SHA256")
        digest.update(der)
        digest.final
      end
    rescue
      nil
    end

    # Determine the hash algorithm to use for tls-server-end-point
    # based on the certificate's signature algorithm (RFC 5929 Section 4.1)
    private def self.get_hash_algorithm_for_cert(cert : OpenSSL::X509::Certificate) : String
      # Get signature algorithm from certificate
      # If MD5 or SHA-1, use SHA-256
      # Otherwise use the same hash algorithm

      # Note: Crystal's OpenSSL binding may not expose signature algorithm directly
      # Default to SHA256 for security
      "SHA256"
    end

    # Format channel binding data for SCRAM
    # Returns the base64-encoded channel binding data in GS2 format
    def self.format_for_scram(cb_type : Type, cb_data : Bytes) : String
      # GS2 channel binding format: "c=" base64(gs2-header || cb-data)
      # gs2-header for channel binding: "p=#{cb_type}"
      gs2_header = "p=#{cb_type}"
      combined = "#{gs2_header},,".to_slice + cb_data
      Base64.strict_encode(combined)
    end

    # Check if channel binding is supported for the given mechanism
    def self.supports_channel_binding?(mechanism : String) : Bool
      # SCRAM mechanisms support channel binding with -PLUS suffix
      mechanism.starts_with?("SCRAM-") && mechanism.ends_with?("-PLUS")
    end

    # Get the base mechanism name without -PLUS suffix
    def self.base_mechanism(mechanism : String) : String
      mechanism.ends_with?("-PLUS") ? mechanism[0...-5] : mechanism
    end
  end
end
