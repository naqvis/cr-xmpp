require "openssl/pkcs5"
require "openssl/hmac"

module XMPP
  # Cryptographic and validation primitives shared by SASL1 and SASL2 SCRAM.
  module SCRAM
    record Response, encoded : String, server_signature : String
    record ServerFirst, raw : String, attributes : Hash(String, String)

    MIN_ITERATIONS =      4096
    MAX_ITERATIONS = 1_000_000

    def self.nonce(bytes : Int32 = 18) : String
      Base64.strict_encode(Random::Secure.random_bytes(bytes))
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def self.parse_server_first(
      encoded : String,
      client_nonce : String,
      min_iterations : Int32 = MIN_ITERATIONS,
      max_iterations : Int32 = MAX_ITERATIONS,
    ) : ServerFirst
      raw = decode_base64_string!(encoded, "SCRAM challenge")
      attributes = Hash(String, String).new
      raw.split(",").each do |attribute|
        separator = attribute.index('=')
        unless separator == 1 && ascii_letter?(attribute.byte_at(0))
          raise AuthenticationError.new("Server sent malformed SCRAM attribute")
        end

        key, value = attribute[0, 1], attribute[2..]
        if attributes.has_key?(key)
          raise AuthenticationError.new("Server sent duplicate SCRAM attribute '#{key}'")
        end
        attributes[key] = value
      end

      if attributes.has_key?("m")
        raise AuthenticationError.new("Server sent reserved SCRAM attribute 'm'")
      end

      iterations = attributes["i"]?.try(&.to_i32?)
      unless iterations && iterations >= min_iterations && iterations <= max_iterations
        raise AuthenticationError.new(
          "Server sent SCRAM iteration count outside #{min_iterations}..#{max_iterations}"
        )
      end

      salt = attributes["s"]? || raise AuthenticationError.new("Server did not send a SCRAM salt")
      decoded_salt = decode_base64!(salt, "SCRAM salt")
      if decoded_salt.empty? || decoded_salt.size > 1024
        raise AuthenticationError.new("Server sent an invalid SCRAM salt")
      end

      nonce = attributes["r"]? || raise AuthenticationError.new("Server did not send a SCRAM nonce")
      unless nonce.starts_with?(client_nonce) && nonce.bytesize > client_nonce.bytesize
        raise AuthenticationError.new("Server SCRAM nonce did not extend the client nonce")
      end

      ServerFirst.new(raw, attributes)
    end

    def self.calculate_response(
      password : String,
      initial_message : String,
      server_first_message : String,
      challenge : Hash(String, String),
      algorithm : OpenSSL::Algorithm,
      gs2_header : String,
      channel_binding_data : Bytes?,
    ) : Response
      cb_input = if channel_binding_data
                   gs2_header.to_slice + channel_binding_data
                 else
                   gs2_header.to_slice
                 end
      bare_message = "c=#{Base64.strict_encode(cb_input)},r=#{challenge["r"]}"
      server_salt = decode_base64!(challenge["s"], "SCRAM salt")
      hasher = digest(algorithm)
      salted_password = OpenSSL::PKCS5.pbkdf2_hmac(
        secret: prepare(password, "password"),
        salt: server_salt,
        iterations: challenge["i"].to_i32,
        algorithm: algorithm,
        key_size: hasher.digest_size
      )
      client_key = OpenSSL::HMAC.digest(algorithm: algorithm, key: salted_password, data: "Client Key")
      hasher.update(client_key)
      stored_key = hasher.final

      auth_message = "#{initial_message},#{server_first_message},#{bare_message}"
      client_signature = OpenSSL::HMAC.digest(algorithm: algorithm, key: stored_key, data: auth_message)
      client_proof = xor(client_key, client_signature)
      server_key = OpenSSL::HMAC.digest(algorithm: algorithm, key: salted_password, data: "Server Key")
      server_signature = OpenSSL::HMAC.digest(algorithm: algorithm, key: server_key, data: auth_message)
      final_message = "#{bare_message},p=#{Base64.strict_encode(client_proof)}"

      Response.new(Base64.strict_encode(final_message), Base64.strict_encode(server_signature))
    end

    def self.verify_server_final!(encoded : String, expected_signature : String) : Nil
      final_message = decode_base64_string!(encoded, "SCRAM server-final-message")
      attributes = final_message.split(",")
      unless attributes.size == 1 && attributes[0].starts_with?("v=")
        raise AuthenticationError.new("Server returned an invalid SCRAM server-final-message")
      end

      actual = decode_base64!(attributes[0][2..], "SCRAM server signature")
      expected = decode_base64!(expected_signature, "expected SCRAM server signature")
      unless secure_compare(actual, expected)
        raise AuthenticationError.new("Server returned a mismatched SCRAM signature")
      end
    end

    def self.secure_compare(left : Bytes, right : Bytes) : Bool
      return false unless left.size == right.size

      difference = 0_u8
      left.each_with_index { |byte, index| difference |= byte ^ right[index] }
      difference == 0
    end

    def self.decode_base64!(value : String, label : String) : Bytes
      Base64.decode(value)
    rescue
      raise AuthenticationError.new("Server sent invalid Base64 for #{label}")
    end

    def self.decode_base64_string!(value : String, label : String) : String
      String.new(decode_base64!(value, label))
    end

    # RFC 4013 requires SASLprep for SCRAM strings. NFKC normalization and the
    # prohibited output classes that can be represented by Crystal strings are
    # enforced here. XMPP JID preparation handles the username before this step.
    def self.prepare(value : String, label : String) : String
      normalized = value.unicode_normalize(:nfkc)
      normalized.each_char do |char|
        codepoint = char.ord
        prohibited = char.control? ||
                     codepoint.in?(0xe000..0xf8ff) ||
                     codepoint.in?(0xf0000..0xffffd) ||
                     codepoint.in?(0x100000..0x10fffd) ||
                     (codepoint & 0xffff).in?(0xfffe..0xffff)
        raise AuthenticationError.new("SCRAM #{label} contains a prohibited character") if prohibited
      end
      normalized
    end

    private def self.digest(algorithm : OpenSSL::Algorithm) : OpenSSL::Digest
      name = if algorithm.sha512?
               "SHA512"
             elsif algorithm.sha256?
               "SHA256"
             else
               "SHA1"
             end
      OpenSSL::Digest.new(name)
    end

    private def self.ascii_letter?(byte : UInt8) : Bool
      byte.in?('a'.ord.to_u8..'z'.ord.to_u8) || byte.in?('A'.ord.to_u8..'Z'.ord.to_u8)
    end

    private def self.xor(left : Bytes, right : Bytes) : Bytes
      raise ArgumentError.new("SCRAM operands have different lengths") unless left.size == right.size
      left.map_with_index { |byte, index| byte ^ right[index] }
    end
  end
end
