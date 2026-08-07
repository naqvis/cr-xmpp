require "./client"
require "./stanza"

module XMPP
  # PrivateXmlStorage is a high-level client for XEP-0049 - Private XML
  # Storage.
  #
  # Private XML storage lets a client persist small amounts of arbitrary XML
  # on the server, keyed by an element's namespace/local name. Stored data is
  # exchanged as a generic Stanza::Node, so any payload can round-trip.
  #
  #   storage = XMPP::PrivateXmlStorage.new(client)
  #   storage.store("storage:bookmarks", "storage", "example")
  #
  #   stored = storage.retrieve("storage:bookmarks", "storage")
  #
  # See: https://xmpp.org/extensions/xep-0049.html
  class PrivateXmlStorage
    # Namespace of the private-storage query wrapper.
    NS_PRIVATE = "jabber:iq:private"

    def initialize(@client : Client)
    end

    # retrieve returns the stored element matching the given namespace and
    # local name as a generic Stanza::Node, or nil when unset (or on error or
    # timeout). The get request carries an empty element so the server knows
    # which data to return.
    def retrieve(namespace : String, name : String, timeout : Time::Span = 5.seconds) : Stanza::Node?
      query = Stanza::PrivateQuery.new
      placeholder = Stanza::Node.new
      placeholder.xml_name = Stanza::XMLName.new(namespace, name)
      query.data = placeholder

      response = @client.request(build_iq("get", query, @client.bare_jid), timeout)
      return nil unless response && response.type == "result"
      payload = response.payload.as?(Stanza::PrivateQuery)
      payload.try(&.data)
    end

    # store persists the given element on the server. Returns the result/error
    # IQ (nil on timeout); callers check type == "result".
    def store(node : Stanza::Node, timeout : Time::Span = 5.seconds) : Stanza::IQ?
      query = Stanza::PrivateQuery.new
      query.data = node
      @client.request(build_iq("set", query, @client.bare_jid), timeout)
    end

    # store is a convenience overload that builds a simple element with the
    # given namespace, local name, and text content.
    def store(namespace : String, name : String, contents : String, timeout : Time::Span = 5.seconds) : Stanza::IQ?
      node = Stanza::Node.new
      node.xml_name = Stanza::XMLName.new(namespace, name)
      node.contents = contents
      store(node, timeout)
    end

    private def build_iq(type : String, payload : Stanza::IQPayload, to : String)
      iq = Stanza::IQ.new
      iq.type = type
      iq.to = to
      iq.payload = payload
      iq
    end
  end
end
