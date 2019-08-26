require "base64"

module XMPP
  private module Auth
    extend self

    def auth_sasl(io, features, user, password)
      # TODO: implement other type of SASL Authentication
      have_plain = false
      features.mechanisms.try &.mechanism.each do |m|
        if m == "PLAIN"
          have_plain = true
          break
        end
      end
      raise "PLAIN authentication is not supported by server: [#{features.mechanisms.try &.mechanism.join}]" unless have_plain
      auth_plain io, user, password
    end

    # Plain authentication: send base64-encoded \x00 user \x00 password
    def auth_plain(io, user, password)
      raw = "\x00#{user}\x00#{password}"
      enc = Base64.encode(raw)
      xml = sprintf "<auth xmlns='%s' mechanism='PLAIN'>%s</auth>", Stanza::NS_SASL, enc
      io.write xml.to_slice

      # Next message should be either success or failure
      val = Stanza::Parser.next_packet read_resp(io)
      if val.is_a?(Stanza::SASLSuccess)
        # we are good
      elsif val.is_a?(Stanza::SASLFailure)
        # v.Any is type of sub-element in failure, which gives a description of what failed
        v = val.as(Stanza::SASLFailure)
        raise "auth failure: #{v.any.try &.to_xml}"
      else
        raise "expected SASL success or failure, got #{val.name}"
      end
    end

    private def read_resp(io)
      b = Bytes.new(1024)
      io.read(b)
      xml = String.new(b)
      document = XML.parse(xml)
      if (r = document.first_element_child)
        r
      else
        raise "Invalid response from server: #{document.to_xml}"
      end
    end
  end
end
