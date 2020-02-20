require "openssl/pkcs5"
require "openssl/hmac"
require "openssl/sha1"

module XMPP
  private class AuthHandler
    def auth_scram(method : String)
      case method
      when "sha256"
        auth_scram_sha("SCRAM-SHA-256", OpenSSL::Algorithm::SHA256)
      when "sha512"
        auth_scram_sha("SCRAM-SHA-512", OpenSSL::Algorithm::SHA512)
      else
        auth_scram_sha("SCRAM-SHA-1", OpenSSL::Algorithm::SHA1)
      end
    end

    # X-SCRAM_SHA_X Auth - https://wiki.xmpp.org/web/SASL_and_SCRAM-SHA-1
    def auth_scram_sha(name, algorithm)
      nonce = nonce(16)
      msg = "n=#{escape(@jid.node || "")},r=#{nonce}"
      raw = "n,,#{msg}"
      enc = Base64.strict_encode(raw)
      send Stanza::SASLAuth.new(mechanism: name, body: enc)
      val = Stanza::Parser.next_packet read_resp
      if val.is_a?(Stanza::SASLChallenge)
        body = val.as(Stanza::SASLChallenge).body
        server_resp = Base64.decode_string(body)
        puts "Server Respnose: #{server_resp}"
        challenge = parse_scram_challenge(body, nonce)
        puts "algorithm: #{algorithm}, challenge: #{challenge}"
        resp, server_sig = scram_response(msg, server_resp, challenge, algorithm)


        send Stanza::SASLResponse.new(resp)
        val = Stanza::Parser.next_packet read_resp
        if val.is_a?(Stanza::SASLSuccess)
          # we are good
          body = val.as(Stanza::SASLSuccess).body
          sig = Base64.decode_string(body)
          raise AuthenticationError.new "Server returned invalid signature on success" unless sig.starts_with?("v=")
          raise AuthenticationError.new "Server returned signature mismatch." unless sig[2..] == server_sig
          Logger.info("#{name} - Auth successful: #{sig}")
        elsif val.is_a?(Stanza::SASLFailure)
          v = val.as(Stanza::SASLFailure)
          raise AuthenticationError.new "#{name} - auth failure: #{v.any.try &.to_xml}"
        else
          raise AuthenticationError.new "#{name} - expected SASL success or failure, got #{val.name}"
        end
      else
        if val.is_a?(Stanza::SASLFailure)
          v = val.as(Stanza::SASLFailure)
          raise AuthenticationError.new "Selected mechanism [#{name}] is not supported by server" if v.type == "invalid-mechanism"
        end
        raise AuthenticationError.new "#{name} - Expecting challenge, got : #{val.to_xml}"
      end
    end

    private def hash_func(algorithm)
      if algorithm.sha512?
        f = "SHA512"
      elsif algorithm.sha256?
        f = "SHA256"
      else
        f = "SHA1"
      end
      OpenSSL::Digest.new(f)
    end

    private def scram_response(initial_msg, server_resp, challenge, algorithm)
      bare_msg = "c=biws,r=#{challenge["r"]}"
      server_salt = Base64.decode(challenge["s"])
      hasher = hash_func(algorithm)
      puts "key_size: #{hasher.digest_size},   server_salt: #{server_salt}"
      salted_pwd = OpenSSL::PKCS5.pbkdf2_hmac(secret: @password, salt: server_salt, iterations: challenge["i"].to_i32,
        algorithm: algorithm, key_size: hasher.digest_size)
      client_key = OpenSSL::HMAC.digest(algorithm: algorithm, key: salted_pwd, data: "Client Key")

      # stored_key = OpenSSL::SHA1.hash(client_key.to_unsafe, LibC::SizeT.new(client_key.bytesize))
      hasher.update(client_key)
      stored_key = hasher.digest

      auth_msg = "#{initial_msg},#{server_resp},#{bare_msg}"
      client_sig = OpenSSL::HMAC.digest(algorithm: algorithm, key: stored_key, data: auth_msg)
      client_proof = xor(client_key, client_sig)

      server_key = OpenSSL::HMAC.digest(algorithm: algorithm, key: salted_pwd, data: "Server Key")
      server_sig = OpenSSL::HMAC.digest(algorithm: algorithm, key: server_key, data: auth_msg)

      final_msg = "#{bare_msg},p=#{Base64.strict_encode(client_proof)}"
      {Base64.strict_encode(final_msg), Base64.strict_encode(server_sig)}
    end

    private def parse_scram_challenge(challenge, nonce)
      value = Base64.decode_string(challenge)
      res = Hash(String, String).new
      value.split(",").each do |v|
        pair = v.split("=")
        key, val = pair[0], v[2..]
        res[key] = val
      end
      # RFC 5802:
      # m: This attribute is reserved for future extensibility.  In this
      # version of SCRAM, its presence in a client or a server message
      # MUST cause authentication failure when the attribute is parsed by
      # the other end.
      raise "Server sent reserved attribute 'm'" if res.has_key?("m")
      if (i = res["i"]?)
        raise "Server sent invalid iteration count" if i.to_i?.nil?
      else
        raise "Server didn't sent iteration count"
      end
      if (salt = res["s"]?)
        raise "Server sent empty salt" if salt.blank?
      else
        raise "Server didn't sent salt"
      end
      if (r = res["r"]?)
        raise "Server sent nonce didn't match" unless r.starts_with?(nonce)
      else
        raise "Server didn't sent nonce"
      end
      res
    end

    private def xor(a : Bytes, b : Bytes)
      if a.bytesize > b.bytesize
        b.map_with_index { |v, i| v ^ a[i] }
      else
        a.map_with_index { |v, i| v ^ b[i] }
      end
    end

    private def escape(str : String)
      # Escape "=" and ","
      str.gsub("=", "=3D").gsub(",", "=2C")
    end
  end
end
