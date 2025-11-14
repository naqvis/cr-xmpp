module XMPP
  # Jabber ID or JID
  #
  # See [RFC 3920 Section 3 - Addressing](http://xmpp.org/rfcs/rfc3920.html#addressing)
  #
  # An entity is anything that can be considered a network endpoint (i.e., an
  # ID on the network) and that can communicate using XMPP. All such entities
  # are uniquely addressable in a form that is consistent with RFC 2396 [URI].
  # For historical reasons, the address of an XMPP entity is called a Jabber
  # Identifier or JID. A valid JID contains a set of ordered elements formed
  # of a domain identifier, node identifier, and resource identifier.
  #
  # The syntax for a JID is defined below using the Augmented Backus-Naur Form
  # as defined in [ABNF]. (The IPv4address and IPv6address rules are defined
  # in Appendix B of [IPv6]; the allowable character sequences that conform to
  # the node rule are defined by the Nodeprep profile of [STRINGPREP] as
  # documented in Appendix A of this memo; the allowable character sequences
  # that conform to the resource rule are defined by the Resourceprep profile
  # of [STRINGPREP] as documented in Appendix B of this memo; and the
  # sub-domain rule makes reference to the concept of an internationalized
  # domain label as described in [IDNA].)
  #
  #     jid             = [ node "@" ] domain [ "/" resource ]
  #     domain          = fqdn / address-literal
  #     fqdn            = (sub-domain 1*("." sub-domain))
  #     sub-domain      = (internationalized domain label)
  #     address-literal = IPv4address / IPv6address
  #
  # All JIDs are based on the foregoing structure. The most common use of this
  # structure is to identify an instant messaging user, the server to which
  # the user connects, and the user"s connected resource (e.g., a specific
  # client) in the form of <user@host/resource>. However, node types other
  # than clients are possible; for example, a specific chat room offered by a
  # multi-user chat service could be addressed as <room@service> (where "room"
  # is the name of the chat room and "service" is the hostname of the
  # multi-user chat service) and a specific occupant of such a room could be
  # addressed as <room@service/nick> (where "nick" is the occupant"s room
  # nickname). Many other JID types are possible (e.g., <domain/resource>
  # could be a server-side script or service).
  #
  # Each allowable portion of a JID (node identifier, domain identifier, and
  # resource identifier) MUST NOT be more than 1023 bytes in size, resulting
  # in a maximum total size (including the "@" and "/" separators) of 3071
  # bytes.

  class JID
    # Validating pattern for JID string
    private PATTERN = /^(?:([^@]*)@)??([^@\/]*)(?:\/(.*?))?$/
    getter node : String?
    getter domain : String
    getter resource : String?

    # JID in standard format "node@domain/resource"
    def self.new(jid : String)
      raise ArgumentError.new "jid cannot be empty" if jid.blank?
      begin
        parsed = jid.match!(PATTERN).captures
      rescue ex
        raise ArgumentError.new "Invalid jid"
      else
        new(parsed[0], parsed[1], parsed[2])
      end
    end

    def initialize(node, domain, resource)
      raise ArgumentError.new "Invalid jid. Domain cannot be empty" if domain.nil? || domain.try &.blank?
      @domain = domain.not_nil!
      raise ArgumentError.new "Domain too long" if @domain.size > 1023
      raise ArgumentError.new "Invalid Node in jid" if (check = @domain.count { |c| ['@', '/', ' '].includes?(c) }) && check > 0

      @node = node
      raise ArgumentError.new "Node too long" if (@node || "").size > 1023
      raise ArgumentError.new "Invalid Node in jid" if (@node.try &.blank?) || (check = @node.try &.count { |c| ['@', '/', '\'', '"', ':', '<', '>'].includes?(c) }) && check > 0

      @resource = resource || "Crystal-XMPP"
      raise ArgumentError.new "Resource too long" if (@resource || "").size > 1023
    end

    # Returns a new JID with resource removed.
    def bare
      s = @domain
      s = "#{@node}@#{s}" if @node
      s
    end

    # Returns Full JID
    def full
      to_s
    end

    # Turn the JID into a string
    #
    # * ""
    # * "domain"
    # * "node@domain"
    # * "domain/resource"
    # * "node@domain/resource"
    #
    # @return [String] the JID as a string
    def to_s
      s = @domain
      s = "#{@node}@#{s}" if @node
      s = "#{s}/#{@resource}" if @resource
      s
    end
  end
end
