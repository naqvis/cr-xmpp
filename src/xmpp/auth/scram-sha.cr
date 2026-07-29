require "openssl/pkcs5"
require "openssl/hmac"
require "openssl/sha1"

require "../channel_binding"

module XMPP
  private class AuthHandler
    def auth_scram(method : String, use_channel_binding : Bool)
      case method
      when "sha256"
        auth_scram_sha("SCRAM-SHA-256", OpenSSL::Algorithm::SHA256, use_channel_binding)
      when "sha512"
        auth_scram_sha("SCRAM-SHA-512", OpenSSL::Algorithm::SHA512, use_channel_binding)
      else
        auth_scram_sha("SCRAM-SHA-1", OpenSSL::Algorithm::SHA1, use_channel_binding)
      end
    end

    # X-SCRAM_SHA_X Auth - https://wiki.xmpp.org/web/SASL_and_SCRAM-SHA-1
    # With optional channel binding support (RFC 5802, RFC 9266)
    # ameba:disable Metrics/CyclomaticComplexity
    def auth_scram_sha(name, algorithm, use_channel_binding : Bool)
      nonce = nonce(16)

      # Get channel binding data if requested and available
      cb_type : ChannelBinding::Type? = nil
      cb_data : Bytes? = nil
      gs2_header = "n,,"

      if use_channel_binding
        if tls_sock = @tls_socket
          advertised = @features.sasl_channel_binding.try(&.types) || [] of String
          if binding = ChannelBinding.get_channel_binding(tls_sock, advertised)
            cb_type, cb_data = binding
            # GS2 header with channel binding: "p=cb-type,,"
            gs2_header = "p=#{cb_type},,"
            name = "#{name}-PLUS" unless name.ends_with?("-PLUS")
          else
            # Channel binding requested but not available - fail
            raise AuthenticationError.new "Channel binding requested but not available for TLS connection"
          end
        else
          raise AuthenticationError.new "Channel binding requested but no TLS connection available"
        end
      end

      msg = "n=#{escape(@jid.node || "")},r=#{nonce}"
      raw = "#{gs2_header}#{msg}"
      enc = Base64.strict_encode(raw)
      send Stanza::SASLAuth.new(mechanism: name, body: enc)
      val = Stanza::Parser.next_packet read_resp
      if val.is_a?(Stanza::SASLChallenge)
        body = val.as(Stanza::SASLChallenge).body
        mechanisms = @features.mechanisms.try(&.mechanism) || [] of String
        server_first = parse_scram_challenge(body, nonce, algorithm, mechanisms)
        resp, server_sig = scram_response(
          msg,
          server_first.raw,
          server_first.attributes,
          algorithm,
          gs2_header,
          cb_data
        )

        send Stanza::SASLResponse.new(resp)
        val = Stanza::Parser.next_packet read_resp
        if val.is_a?(Stanza::SASLSuccess)
          # we are good
          body = val.as(Stanza::SASLSuccess).body
          verify_scram_server_final!(body, server_sig)
          Logger.info("#{name} - Auth successful")
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

    private def scram_response(initial_msg, server_resp, challenge, algorithm, gs2_header, cb_data : Bytes?)
      response = SCRAM.calculate_response(
        @password,
        initial_msg,
        server_resp,
        challenge,
        algorithm,
        gs2_header,
        cb_data
      )
      {response.encoded, response.server_signature}
    end

    private def parse_scram_challenge(challenge, nonce, algorithm, mechanisms : Array(String))
      server_first = SCRAM.parse_server_first(challenge, nonce)
      attributes = server_first.attributes
      TLSChannelBindingDowngradeProtection.verify!(
        attributes["t"]?,
        @tls_socket.try &.tls_version
      )
      ScramDowngradeProtection.verify!(
        attributes["h"]?,
        mechanisms,
        @features.sasl_channel_binding.try(&.types) || [] of String,
        algorithm
      )
      server_first
    end

    private def verify_scram_server_final!(encoded : String, expected_signature : String)
      SCRAM.verify_server_final!(encoded, expected_signature)
    end

    private def escape(str : String)
      # Escape "=" and ","
      SCRAM.prepare(str, "username").gsub("=", "=3D").gsub(",", "=2C")
    end
  end
end
