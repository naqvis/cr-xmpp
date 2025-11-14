module XMPP
  # XEP-0474: SASL SCRAM Downgrade Protection
  # Protects against downgrade attacks where an attacker forces the client
  # to use a weaker authentication mechanism
  module ScramDowngradeProtection
    # Check if downgrade protection should be enforced
    # Returns true if a SCRAM-PLUS mechanism is available but a non-PLUS was selected
    def self.check_downgrade(
      selected_mechanism : AuthMechanism,
      available_mechanisms : Array(String),
      tls_available : Bool,
    ) : Bool
      # Only check if we're using a non-PLUS SCRAM mechanism
      return false unless selected_mechanism.to_s.starts_with?("SCRAM-")
      return false if selected_mechanism.uses_channel_binding?
      return false unless tls_available

      # Check if server advertises the -PLUS variant
      base_name = selected_mechanism.to_s
      plus_variant = "#{base_name}-PLUS"

      if available_mechanisms.includes?(plus_variant)
        # Server supports -PLUS but we're using non-PLUS
        # This could be a downgrade attack
        Logger.warn "Potential downgrade attack detected: Server supports #{plus_variant} but #{base_name} was selected"
        return true
      end

      false
    end

    # Get the recommended mechanism considering downgrade protection
    # Prefers -PLUS variants when TLS is available
    def self.select_mechanism(
      preferred_order : Array(AuthMechanism),
      available_mechanisms : Array(String),
      tls_available : Bool,
    ) : AuthMechanism?
      preferred_order.each do |mechanism|
        if available_mechanisms.includes?(mechanism.to_s)
          # Check for potential downgrade
          if check_downgrade(mechanism, available_mechanisms, tls_available)
            # Skip this mechanism and try the -PLUS variant
            next
          end
          return mechanism
        end
      end
      nil
    end
  end
end
