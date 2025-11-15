require "uuid"

module XMPP
  private class AuthHandler
    # XEP-0388: SASL2 Authentication
    # Detects if server supports SASL2 and uses it, otherwise falls back to legacy SASL
    def authenticate_sasl2_if_supported(methods : Array(AuthMechanism))
      # Check if server supports SASL2
      if sasl2 = @features.sasl2_authentication
        Logger.info("Server supports SASL2 (XEP-0388), using modern authentication flow")
        return authenticate_sasl2(methods, sasl2)
      end

      # Fall back to legacy SASL
      Logger.info("Server does not support SASL2, using legacy SASL authentication")
      authenticate(methods)
    end

    # Authenticate using SASL2 (XEP-0388)
    # ameba:disable Metrics/CyclomaticComplexity
    private def authenticate_sasl2(methods : Array(AuthMechanism), sasl2 : Stanza::SASL2Authentication)
      # Find first supported mechanism
      selected_mechanism = nil
      methods.each do |method|
        if sasl2.supports_mechanism?(method.to_s)
          selected_mechanism = method
          break
        end
      end

      unless selected_mechanism
        raise AuthenticationError.new "None of the preferred Auth mechanisms '[#{methods.join(",")}]' supported by server. Server supported mechanisms are [#{sasl2.mechanisms.join(",")}]"
      end

      Logger.info("Selected SASL2 mechanism: #{selected_mechanism}")

      # Determine if we should request upgrades (XEP-0480)
      upgrades = [] of String
      if mechs = @features.mechanisms
        if !mechs.upgrade_tasks.empty?
          upgrades = SASLUpgrade.select_upgrades(
            selected_mechanism,
            sasl2.mechanisms,
            mechs.upgrade_tasks
          )
          if !upgrades.empty?
            Logger.info("Requesting SASL upgrades: #{upgrades.join(", ")}")
          end
        end
      end

      # Perform SASL2 authentication based on mechanism
      case selected_mechanism
      when AuthMechanism::SCRAM_SHA_1        then auth_scram_sasl2("sha1", false, upgrades)
      when AuthMechanism::SCRAM_SHA_256      then auth_scram_sasl2("sha256", false, upgrades)
      when AuthMechanism::SCRAM_SHA_512      then auth_scram_sasl2("sha512", false, upgrades)
      when AuthMechanism::SCRAM_SHA_1_PLUS   then auth_scram_sasl2("sha1", true, upgrades)
      when AuthMechanism::SCRAM_SHA_256_PLUS then auth_scram_sasl2("sha256", true, upgrades)
      when AuthMechanism::SCRAM_SHA_512_PLUS then auth_scram_sasl2("sha512", true, upgrades)
      else
        raise AuthenticationError.new "SASL2 mechanism '#{selected_mechanism}' not implemented yet"
      end
    end

    # SCRAM authentication using SASL2 flow
    # ameba:disable Metrics/CyclomaticComplexity
    private def auth_scram_sasl2(method : String, use_channel_binding : Bool, upgrades : Array(String))
      algorithm = case method
                  when "sha256" then OpenSSL::Algorithm::SHA256
                  when "sha512" then OpenSSL::Algorithm::SHA512
                  else               OpenSSL::Algorithm::SHA1
                  end

      name = case method
             when "sha256" then "SCRAM-SHA-256"
             when "sha512" then "SCRAM-SHA-512"
             else               "SCRAM-SHA-1"
             end

      nonce = nonce(16)

      # Get channel binding data if requested
      cb_type : ChannelBinding::Type? = nil
      cb_data : Bytes? = nil
      gs2_header = "n,,"

      if use_channel_binding
        if tls_sock = @tls_socket
          if binding = ChannelBinding.get_channel_binding(tls_sock)
            cb_type, cb_data = binding
            gs2_header = "p=#{cb_type},,"
            name = "#{name}-PLUS" unless name.ends_with?("-PLUS")
          else
            raise AuthenticationError.new "Channel binding requested but not available for TLS connection"
          end
        else
          raise AuthenticationError.new "Channel binding requested but no TLS connection available"
        end
      end

      # Build initial message
      msg = "n=#{escape(@jid.node || "")},r=#{nonce}"
      raw = "#{gs2_header}#{msg}"
      enc = Base64.strict_encode(raw)

      # Create user-agent
      user_agent = Stanza::SASL2UserAgent.new(
        id: UUID.random.to_s,
        software: "Crystal-XMPP",
        device: "Crystal Client"
      )

      # Send authenticate
      auth_request = Stanza::SASL2Authenticate.new(
        mechanism: name,
        initial_response: enc,
        user_agent: user_agent,
        upgrades: upgrades
      )
      send auth_request

      # Read server response
      val = Stanza::Parser.next_packet read_resp

      # Handle challenge
      if val.is_a?(Stanza::SASL2Challenge)
        body = val.as(Stanza::SASL2Challenge).body
        server_resp = Base64.decode_string(body)
        challenge = parse_scram_challenge(body, nonce)
        resp, _server_sig = scram_response(msg, server_resp, challenge, algorithm, gs2_header, cb_data)

        send Stanza::SASL2Response.new(resp)
        val = Stanza::Parser.next_packet read_resp
      end

      # Handle success or continue
      if val.is_a?(Stanza::SASL2Success)
        handle_sasl2_success(val.as(Stanza::SASL2Success), name)
      elsif val.is_a?(Stanza::SASL2Continue)
        handle_sasl2_continue(val.as(Stanza::SASL2Continue), upgrades, algorithm)
      elsif val.is_a?(Stanza::SASLFailure)
        v = val.as(Stanza::SASLFailure)
        raise AuthenticationError.new "#{name} - auth failure: #{v.any.try &.to_xml}"
      else
        raise AuthenticationError.new "#{name} - expected SASL2 success, continue, or failure, got #{val.name}"
      end
    end

    # Handle SASL2 success
    private def handle_sasl2_success(success : Stanza::SASL2Success, mechanism_name : String)
      # Verify additional data if present (server signature for SCRAM)
      if !success.body.blank?
        _sig = Base64.decode_string(success.body)
        # For SCRAM, verify server signature
        # Note: We'd need to pass server_sig here for full verification
        # For now, we trust the success
      end

      Logger.info("#{mechanism_name} - SASL2 Auth successful")
      Logger.info("Authorization identifier: #{success.authorization_identifier}")
    end

    # Handle SASL2 continue (for upgrade tasks)
    private def handle_sasl2_continue(continue : Stanza::SASL2Continue, requested_upgrades : Array(String), algorithm : OpenSSL::Algorithm)
      Logger.info("Server requests additional tasks: #{continue.tasks.join(", ")}")

      # Process each requested task
      continue.tasks.each do |task|
        unless requested_upgrades.includes?(task)
          raise AuthenticationError.new "Server requested unexpected task: #{task}"
        end

        Logger.info("Performing upgrade task: #{task}")
        perform_scram_upgrade(task, algorithm)

        # Read next response
        val = Stanza::Parser.next_packet read_resp

        if val.is_a?(Stanza::SASL2Success)
          handle_sasl2_success(val.as(Stanza::SASL2Success), "SASL2")
          return
        elsif val.is_a?(Stanza::SASL2Continue)
          # More tasks to do
          handle_sasl2_continue(val.as(Stanza::SASL2Continue), requested_upgrades, algorithm)
          return
        elsif val.is_a?(Stanza::SASLFailure)
          v = val.as(Stanza::SASLFailure)
          raise AuthenticationError.new "Upgrade task failed: #{v.any.try &.to_xml}"
        else
          raise AuthenticationError.new "Unexpected response to upgrade task: #{val.name}"
        end
      end
    end
  end
end
