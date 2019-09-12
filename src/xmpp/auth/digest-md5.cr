require "base64"
require "openssl/md5.cr"
require "digest/md5.cr"

module XMPP
  private class AuthHandler
    # DIGEST-MD5 Auth - https://wiki.xmpp.org/web/SASL_and_DIGEST-MD5
    def auth_digest_md5
      send Stanza::SASLAuth.new(mechanism: "DIGEST-MD5")
      val = Stanza::Parser.next_packet read_resp
      if val.is_a?(Stanza::SASLChallenge)
        challenge = val.as(Stanza::SASLChallenge).body
        body = do_response(parse_digest_challenge(challenge))
        send Stanza::SASLResponse.new(body)
        val = Stanza::Parser.next_packet read_resp
        if val.is_a?(Stanza::SASLChallenge)
          # we are good
          challenge = val.as(Stanza::SASLChallenge).body
          Logger.info("digest-md5 - Auth successful: #{Base64.decode_string(challenge)}")
          handle_success
        elsif val.is_a?(Stanza::SASLFailure)
          v = val.as(Stanza::SASLFailure)
          raise "digest-md5 - auth failure: #{v.any.try &.to_xml}"
        else
          raise "digest-md5 - expected SASL success or failure, got #{val.name}"
        end
      else
        raise "digest-md5 - Expecting challenge, got : #{val.to_xml}"
      end
    end

    private def parse_digest_challenge(challenge : String)
      val = Base64.decode_string(challenge)
      res = Hash(String, String).new
      val.split(",").each do |v|
        pair = v.split("=")
        key, val = pair[0], pair[1].strip('"')
        next if key == "qop" && val != "auth"
        raise "Invalid challenge. algorithm provided multiple times" if key == "algorithm" && res.has_key?("algorithm")
        raise "Invalid challenge. charset provided multiple times" if key == "charset" && res.has_key?("charset")
        res[key] = val
      end
      res["realm"] = @jid.domain unless res.has_key?("realm")
      raise "Invalid challenge. nonce not found" unless res.has_key?("nonce")
      raise "Invalid challenge. qop not found" unless res.has_key?("qop")
      raise "Invalid challenge. algorithm not found" unless res.has_key?("algorithm")
      res
    end

    private def do_response(challenge)
      res = Hash{
        "nonce"      => challenge["nonce"],
        "charset"    => challenge["charset"],
        "username"   => @jid.node,
        "realm"      => challenge["realm"],
        "cnonce"     => nonce(16),
        "nc"         => "00000001",
        "qop"        => challenge["qop"],
        "digest-uri" => "xmpp/#{@jid.domain}",
      }
      res["response"] = make_response(res)
      vals = %w(nc qop response charset)
      sb = String.build do |str|
        res.each do |k, v|
          str << k << "="
          if !vals.includes?(k)
            str << "\"" << v << "\""
          else
            str << v
          end
          str << ","
        end
      end
      Base64.strict_encode(sb.rstrip(","))
    end

    private def make_response(res)
      x = "#{res["username"]}:#{res["realm"]}:#{@password}"
      y = String.new(OpenSSL::MD5.hash(x).to_slice)
      a1 = "#{y}:#{res["nonce"]}:#{res["cnonce"]}"
      a2 = "AUTHENTICATE:#{res["digest-uri"]}"
      ha1 = Digest::MD5.hexdigest(a1)
      ha2 = Digest::MD5.hexdigest(a2)
      kd = "#{ha1}:#{res["nonce"]}:#{res["nc"]}:#{res["cnonce"]}:#{res["qop"]}:#{ha2}"
      Digest::MD5.hexdigest(kd)
    end

    private def handle_success
      send Stanza::SASLResponse.new
      handle_resp("digest-md5")
    end
  end
end
