require "./client"
require "./stanza"

module XMPP
  # ClientStateIndication is a high-level client for XEP-0352 - Client State
  # Indication.
  #
  # A client signals whether it is in the foreground or background by sending
  # the empty stream nonzas <active/> / <inactive/> in the urn:xmpp:csi:0
  # namespace. The server may use this to stop or throttle traffic to
  # backgrounded clients. There is no reply and no discovery step.
  #
  #   csi = XMPP::ClientStateIndication.new(client)
  #   csi.inactive  # move to the background
  #   csi.active    # return to the foreground
  #
  # See: https://xmpp.org/extensions/xep-0352.html
  class ClientStateIndication
    def initialize(@client : Client)
    end

    # active tells the server the client has returned to the foreground.
    def active
      @client.send Stanza::CSIActive.new.to_xml
    end

    # inactive tells the server the client moved to the background.
    def inactive
      @client.send Stanza::CSIInactive.new.to_xml
    end
  end
end
