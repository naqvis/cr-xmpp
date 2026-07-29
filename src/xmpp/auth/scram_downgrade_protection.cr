module XMPP
  # XEP-0474: SASL SCRAM Downgrade Protection
  module ScramDowngradeProtection
    RECORD_SEPARATOR = '\u001e'
    UNIT_SEPARATOR   = '\u001f'

    def self.calculate_hash(
      mechanisms : Array(String),
      channel_binding_types : Array(String),
      algorithm : OpenSSL::Algorithm,
    ) : String
      input = String.build do |value|
        value << octet_sort(mechanisms).join(RECORD_SEPARATOR)
        unless channel_binding_types.empty?
          value << UNIT_SEPARATOR
          value << octet_sort(channel_binding_types).join(RECORD_SEPARATOR)
        end
      end

      digest = OpenSSL::Digest.new(digest_name(algorithm))
      digest.update(input)
      Base64.strict_encode(digest.final)
    end

    def self.verify!(
      server_hash : String?,
      mechanisms : Array(String),
      channel_binding_types : Array(String),
      algorithm : OpenSSL::Algorithm,
    ) : Nil
      return unless server_hash

      actual = SCRAM.decode_base64!(server_hash, "XEP-0474 downgrade-protection hash")
      expected = SCRAM.decode_base64!(
        calculate_hash(mechanisms, channel_binding_types, algorithm),
        "expected XEP-0474 downgrade-protection hash"
      )
      return if SCRAM.secure_compare(actual, expected)

      raise AuthenticationError.new(
        "SASL mechanism or channel-binding downgrade detected by XEP-0474"
      )
    end

    # Retained as a public policy helper for callers selecting mechanisms.
    def self.check_downgrade(
      selected_mechanism : AuthMechanism,
      available_mechanisms : Array(String),
      tls_available : Bool,
    ) : Bool
      return false unless selected_mechanism.to_s.starts_with?("SCRAM-")
      return false if selected_mechanism.uses_channel_binding?
      return false unless tls_available

      available_mechanisms.includes?("#{selected_mechanism}-PLUS")
    end

    def self.select_mechanism(
      preferred_order : Array(AuthMechanism),
      available_mechanisms : Array(String),
      tls_available : Bool,
    ) : AuthMechanism?
      preferred_order.find do |mechanism|
        available_mechanisms.includes?(mechanism.to_s) &&
          !check_downgrade(mechanism, available_mechanisms, tls_available)
      end
    end

    private def self.octet_sort(values : Array(String)) : Array(String)
      values.sort do |left, right|
        compare_octets(left.to_slice, right.to_slice)
      end
    end

    private def self.compare_octets(left : Bytes, right : Bytes) : Int32
      limit = Math.min(left.size, right.size)
      limit.times do |index|
        comparison = left[index] <=> right[index]
        return comparison unless comparison == 0
      end
      left.size <=> right.size
    end

    private def self.digest_name(algorithm : OpenSSL::Algorithm) : String
      return "SHA512" if algorithm.sha512?
      return "SHA256" if algorithm.sha256?
      "SHA1"
    end
  end
end
