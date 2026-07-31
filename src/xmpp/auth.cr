require "./event_manager"
require "./auth/*"
require "./channel_binding"
require "./stanza/sasl_upgrade"

module XMPP
  class AuthenticationError < PermanentConnectionError; end

  enum AuthMechanism
    # SCRAM with channel binding (preferred)
    SCRAM_SHA_512_PLUS
    SCRAM_SHA_256_PLUS
    SCRAM_SHA_1_PLUS
    # SCRAM without channel binding
    SCRAM_SHA_512
    SCRAM_SHA_256
    SCRAM_SHA_1
    DIGEST_MD5
    PLAIN
    ANONYMOUS

    def to_s
      s = AuthMechanism.names[self.value]
      s.gsub("_", "-")
    end

    # Check if this mechanism uses channel binding
    def uses_channel_binding? : Bool
      case self
      when SCRAM_SHA_512_PLUS, SCRAM_SHA_256_PLUS, SCRAM_SHA_1_PLUS
        true
      else
        false
      end
    end

    # PLAIN exposes a reusable password to the authenticated peer and must
    # therefore only be used over a verified TLS connection.
    def requires_verified_tls? : Bool
      plain?
    end

    # DIGEST-MD5 uses a challenge flow that is currently implemented only for
    # classic SASL. The other compatibility mechanisms can use SASL2 directly.
    def supported_by_sasl2? : Bool
      !digest_md5?
    end

    # Get the base mechanism without -PLUS suffix
    def base_mechanism : String
      to_s.sub("-PLUS", "")
    end
  end

  # Preferred authentication order: SCRAM-PLUS variants first (more secure with channel binding)
  SASL_AUTH_ORDER = [
    AuthMechanism::SCRAM_SHA_512_PLUS, AuthMechanism::SCRAM_SHA_256_PLUS, AuthMechanism::SCRAM_SHA_1_PLUS,
    AuthMechanism::SCRAM_SHA_512, AuthMechanism::SCRAM_SHA_256, AuthMechanism::SCRAM_SHA_1,
  ]

  # Explicit opt-in order for compatibility with servers that still require
  # obsolete or cleartext-password SASL mechanisms.
  LEGACY_SASL_AUTH_ORDER = SASL_AUTH_ORDER + [
    AuthMechanism::DIGEST_MD5,
    AuthMechanism::PLAIN,
    AuthMechanism::ANONYMOUS,
  ]

  private class AuthHandler
    @io : IO
    @reader : XMLStreamReader
    @password : String
    @jid : JID
    @features : Stanza::StreamFeatures
    @tls_socket : OpenSSL::SSL::Socket::Client?
    @tls_verified : Bool
    @request_bind2 : Bool
    getter bound_jid : String? = nil
    getter? used_sasl2 : Bool = false

    def initialize(
      @io,
      @reader,
      @features,
      @password,
      @jid,
      @tls_socket = nil,
      @tls_verified = false,
      @request_bind2 = true,
    )
      sasl1_count = @features.mechanisms.try(&.mechanism.size) || 0
      sasl2_count = @features.sasl2_authentication.try(&.mechanisms.size) || 0
      raise AuthenticationError.new "Server returned empty list of Authentication mechanisms" unless sasl1_count > 0 || sasl2_count > 0
    end

    def authenticate(methods : Array(AuthMechanism))
      # Try SASL2 first if available
      if @features.supports_sasl2?
        return authenticate_sasl2_if_supported(methods)
      end

      authenticate_legacy(methods)
    end

    private def authenticate_legacy(methods : Array(AuthMechanism))
      if mechanisms = @features.mechanisms.try &.mechanism
        if method = select_mechanism(methods, mechanisms)
          return do_auth(method)
        end
        raise_insecure_plain_if_applicable(methods, mechanisms)
        raise AuthenticationError.new "None of the preferred Auth mechanism '[#{methods.join(",")}]' supported by server. Server supported mechanisms are [#{mechanisms.join(",")}]"
      else
        raise AuthenticationError.new "Server returned empty list of Authentication mechanisms"
      end
    end

    private def select_mechanism(
      methods : Array(AuthMechanism),
      advertised : Array(String),
      sasl2 = false,
    ) : AuthMechanism?
      methods.find do |method|
        next false unless advertised.includes?(method.to_s)
        next false if sasl2 && !method.supported_by_sasl2?
        next false if method.requires_verified_tls? && !@tls_verified
        next false if method.uses_channel_binding? && !channel_binding_available?
        true
      end
    end

    private def raise_insecure_plain_if_applicable(methods, advertised)
      if !@tls_verified &&
         methods.includes?(AuthMechanism::PLAIN) &&
         advertised.includes?(AuthMechanism::PLAIN.to_s)
        raise AuthenticationError.new "PLAIN authentication requires a verified TLS connection"
      end
    end

    private def do_auth(method : AuthMechanism)
      case method
      when AuthMechanism::DIGEST_MD5         then auth_digest_md5
      when AuthMechanism::PLAIN              then auth_plain
      when AuthMechanism::ANONYMOUS          then auth_anonymous
      when AuthMechanism::SCRAM_SHA_1        then auth_scram("sha1", false)
      when AuthMechanism::SCRAM_SHA_256      then auth_scram("sha256", false)
      when AuthMechanism::SCRAM_SHA_512      then auth_scram("sha512", false)
      when AuthMechanism::SCRAM_SHA_1_PLUS   then auth_scram("sha1", true)
      when AuthMechanism::SCRAM_SHA_256_PLUS then auth_scram("sha256", true)
      when AuthMechanism::SCRAM_SHA_512_PLUS then auth_scram("sha512", true)
      else
        raise AuthenticationError.new "Auth mechanism '#{method}' not implemented. Currently implemented mechanisms are [#{LEGACY_SASL_AUTH_ORDER.join(",")}]"
      end
    end

    private def channel_binding_available? : Bool
      return false unless socket = @tls_socket
      advertised = @features.sasl_channel_binding.try(&.types) || [] of String
      !ChannelBinding.get_channel_binding(socket, advertised).nil?
    end

    private def read_resp
      @reader.read_node
    end

    private def send(xml : String)
      @io.write xml.to_slice
    end

    private def send(packet : Stanza::Packet)
      send(packet.to_xml)
    end

    private def handle_resp(tag)
      # Next message should be either success or failure
      val = Stanza::Parser.next_packet read_resp
      if val.is_a?(Stanza::SASLSuccess)
        # we are good
      elsif val.is_a?(Stanza::SASLFailure)
        # v.Any is type of sub-element in failure, which gives a description of what failed
        v = val.as(Stanza::SASLFailure)
        raise AuthenticationError.new "#{tag} - auth failure: #{v.any.try &.to_xml}"
      else
        raise AuthenticationError.new "#{tag} - expected SASL success or failure, got #{val.name}"
      end
    end

    private def nonce(n : Int32)
      Base64.strict_encode(Random::Secure.random_bytes(n))
    end
  end
end
