module XMPP::Stanza
  record XMLName, space : String, local : String do
    def self.new(tag : String)
      parts = tag.split(" ")
      parts += [" "] if parts.size == 1
      raise ArgumentError.new "Invalid Tag: #{tag}" unless parts.size == 2
      new(parts[0], parts[1])
    end

    def to_s
      "#{space} #{local}"
    end
  end

  # Namespace Constants
  NS_STREAM            = "http://etherx.jabber.org/streams"
  NS_STREAM_MANAGEMENT = "urn:xmpp:sm:3"
  NS_TLS               = "urn:ietf:params:xml:ns:xmpp-tls"
  NS_SASL              = "urn:ietf:params:xml:ns:xmpp-sasl"
  NS_BIND              = "urn:ietf:params:xml:ns:xmpp-bind"
  NS_SESSION           = "urn:ietf:params:xml:ns:xmpp-session"
  NS_CLIENT            = "jabber:client"
  NS_COMPONENT         = "jabber:component:accept"
end

require "./stanza/*"
