module XMPP
  # An adapter to allow the use of blocks and ordinary functions
  # as XMPP handlers.
  alias Callback = (Sender, Stanza::Packet) ->

  # Sender is an interface provided by Stream clients to allow sending XMPP data.
  # It is mostly use in callback to pass a limited subset of the stream client interface

  module Sender
    abstract def send(packet : Stanza::Packet)
    abstract def send(packet : String)
  end

  # StreamClient is an interface used by StreamManager to control Client lifecycle,
  # set callback and trigger reconnection.
  module StreamClient
    include Sender

    abstract def connect
    abstract def resume(state : SMState)
    abstract def disconnect
    abstract def event_handler=(handler : EventHandler)
  end
end

require "./*"
