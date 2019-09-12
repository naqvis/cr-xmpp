require "./auth/*"

module XMPP
  class AuthenticationError < Exception; end

  enum AuthMechanism
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
  end

  SASL_AUTH_ORDER = [AuthMechanism::SCRAM_SHA_512, AuthMechanism::SCRAM_SHA_256, AuthMechanism::SCRAM_SHA_1,
                     AuthMechanism::DIGEST_MD5, AuthMechanism::PLAIN,
                     AuthMechanism::ANONYMOUS]

  private class AuthHandler
    @io : IO
    @password : String
    @jid : JID
    @features : Stanza::StreamFeatures

    def initialize(@io, @features, @password, @jid)
      raise AuthenticationError.new "Server returned empty list of Authentication mechanisms" unless (@features.mechanisms.try &.mechanism.size || 0) > 0
    end

    def authenticate(methods : Array(AuthMechanism))
      if (mechanisms = @features.mechanisms.try &.mechanism)
        methods.each do |method|
          if mechanisms.includes? method.to_s
            return do_auth(method)
          end
        end
        raise AuthenticationError.new "None of the preferred Auth mechanism '[#{methods.join(",")}]' supported by server. Server supported mechanisms are [#{mechanisms.join(",")}]"
      else
        raise AuthenticationError.new "Server returned empty list of Authentication mechanisms"
      end
    end

    private def do_auth(method : AuthMechanism)
      case method
      when AuthMechanism::DIGEST_MD5    then auth_digest_md5
      when AuthMechanism::PLAIN         then auth_plain
      when AuthMechanism::ANONYMOUS     then auth_anonymous
      when AuthMechanism::SCRAM_SHA_1   then auth_scram("sha1")
      when AuthMechanism::SCRAM_SHA_256 then auth_scram("sha256")
      when AuthMechanism::SCRAM_SHA_512 then auth_scram("sha512")
      else
        raise AuthenticationError.new "Auth mechanism '#{method.to_s}' not implemented. Currently implemented mechanisms are [#{SASL_AUTH_ORDER.join(",")}]"
      end
    end

    private def read_resp
      b = Bytes.new(1024)
      @io.read(b)
      xml = String.new(b)
      document = XML.parse(xml)
      if (r = document.first_element_child)
        r
      else
        raise "Invalid response from server: #{document.to_xml}"
      end
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
      b = Bytes.new(n)
      Random.new.random_bytes(b)
      Base64.strict_encode(b)
    end
  end
end
