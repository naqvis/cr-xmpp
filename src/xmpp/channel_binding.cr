require "openssl"
require "base64"

lib LibSSL
  fun ssl_export_keying_material = SSL_export_keying_material(
    ssl : SSL,
    output : UInt8*,
    output_length : LibC::SizeT,
    label : UInt8*,
    label_length : LibC::SizeT,
    context : UInt8*,
    context_length : LibC::SizeT,
    use_context : Int32,
  ) : Int32
  fun ssl_get_finished = SSL_get_finished(ssl : SSL, buffer : Void*, count : LibC::SizeT) : LibC::SizeT
end

class OpenSSL::SSL::Socket
  def xmpp_export_keying_material(label : String, length : Int32) : Bytes?
    output = Bytes.new(length)
    result = LibSSL.ssl_export_keying_material(
      @ssl,
      output,
      output.size,
      label.to_unsafe,
      label.bytesize,
      Pointer(UInt8).null,
      0,
      0
    )
    result == 1 ? output : nil
  end

  def xmpp_tls_unique : Bytes?
    size = LibSSL.ssl_get_finished(@ssl, Pointer(Void).null, 0)
    return nil if size == 0

    output = Bytes.new(size)
    written = LibSSL.ssl_get_finished(@ssl, output.to_unsafe.as(Void*), output.size)
    written == size ? output : nil
  end
end

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
    # ameba:disable Metrics/CyclomaticComplexity
    def self.get_channel_binding(
      socket : OpenSSL::SSL::Socket::Client,
      advertised_types : Array(String)? = nil,
    ) : Tuple(Type, Bytes)?
      tls_version = get_tls_version(socket)

      case tls_version
      when "TLSv1.3"
        # For TLS 1.3, prefer tls-exporter, fallback to tls-server-end-point
        if allowed?(Type::TLS_EXPORTER, advertised_types) && (data = get_tls_exporter(socket))
          {Type::TLS_EXPORTER, data}
        elsif allowed?(Type::TLS_SERVER_END_POINT, advertised_types) && (data = get_tls_server_end_point(socket))
          {Type::TLS_SERVER_END_POINT, data}
        else
          nil
        end
      when "TLSv1.2"
        # For TLS 1.2 and earlier, prefer tls-unique, fallback to tls-server-end-point
        if allowed?(Type::TLS_UNIQUE, advertised_types) && (data = get_tls_unique(socket))
          {Type::TLS_UNIQUE, data}
        elsif allowed?(Type::TLS_SERVER_END_POINT, advertised_types) && (data = get_tls_server_end_point(socket))
          {Type::TLS_SERVER_END_POINT, data}
        else
          nil
        end
      else
        nil
      end
    end

    # Get TLS version string from socket
    private def self.get_tls_version(socket : OpenSSL::SSL::Socket::Client) : String
      socket.tls_version
    end

    # RFC 9266: tls-exporter channel binding for TLS 1.3
    # Uses the TLS exporter mechanism with label "EXPORTER-Channel-Binding"
    private def self.get_tls_exporter(socket : OpenSSL::SSL::Socket::Client) : Bytes?
      # TLS 1.3 exporter: RFC 8446 Section 7.5
      # Label: "EXPORTER-Channel-Binding" (RFC 9266)
      # Context: empty
      # Length: 32 bytes

      socket.xmpp_export_keying_material("EXPORTER-Channel-Binding", 32)
    end

    # RFC 5929: tls-unique channel binding for TLS <= 1.2
    # Uses the Finished message from the TLS handshake
    private def self.get_tls_unique(socket : OpenSSL::SSL::Socket::Client) : Bytes?
      # The tls-unique channel binding is the first Finished message
      # sent in the most recent handshake

      socket.xmpp_tls_unique
    end

    # RFC 5929: tls-server-end-point channel binding
    # Uses the hash of the server's certificate
    private def self.get_tls_server_end_point(socket : OpenSSL::SSL::Socket::Client) : Bytes?
      return nil unless cert = socket.peer_certificate

      hash_algorithm = get_hash_algorithm_for_cert(cert)
      cert.digest(hash_algorithm)
    rescue
      nil
    end

    # Determine the hash algorithm to use for tls-server-end-point
    # based on the certificate's signature algorithm (RFC 5929 Section 4.1)
    private def self.get_hash_algorithm_for_cert(cert : OpenSSL::X509::Certificate) : String
      signature = cert.signature_algorithm.upcase
      return "SHA256" if signature.includes?("MD5") || signature.includes?("SHA1")
      return "SHA224" if signature.includes?("SHA224")
      return "SHA256" if signature.includes?("SHA256")
      return "SHA384" if signature.includes?("SHA384")
      return "SHA512" if signature.includes?("SHA512")
      raise AuthenticationError.new("Unsupported certificate signature algorithm '#{signature}'")
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

    private def self.allowed?(type : Type, advertised_types : Array(String)?) : Bool
      advertised_types.nil? || advertised_types.includes?(type.to_s)
    end
  end
end
