require "./xmpp"

module XMPP
  # Event Manager
  # EventHandler is use to pass events about state of the connection to
  # client implementation.
  alias EventHandler = (Event) ->

  class ConnectionClosed < Exception; end

  # ConnectionState represents the current connection state.
  # This is a list of events happening on the connection that
  # the client can be notified about.
  enum ConnectionState
    Disconnected
    Connected
    SessionEstablished
    StreamError
  end

  # SMState holds Stream Management information regarding the session that can be
  # used to resume session after disconnect
  # TODO: Store location for IP affinity
  # TODO: Store max and timestamp, to check if we should retry resumption or not
  class SMState
    property id : String      # Stream Management ID
    property inbound : UInt32 # Inbound stanza count

    def initialize(@id = "", @inbound = 0_u32)
    end
  end

  # Event is a structure use to convey event changes related to client state. This
  # is for example used to notify the client when the client get disconnected.

  struct Event
    property state : ConnectionState
    property description : String
    property stream_error : String
    property sm_state : SMState

    def initialize(@state = ConnectionState::Disconnected,
                   @description = "", @stream_error = "",
                   @sm_state = SMState.new)
    end
  end

  module EventManager
    # Store current state
    @current_state : ConnectionState = ConnectionState::Disconnected
    # Callback used to propagate connection state changes
    property event_handler : EventHandler? = nil

    private def update_state(state : ConnectionState)
      @current_state = state
      @event_handler.try &.call Event.new(state: state)
    end

    private def disconnected(state : SMState)
      @current_state = ConnectionState::Disconnected
      @event_handler.try &.call Event.new(
        state: @current_state,
        sm_state: state)
    end

    private def stream_error(error : String, desc : String)
      @current_state = ConnectionState::StreamError
      @event_handler.try &.call Event.new(
        state: @current_state,
        stream_error: error,
        description: desc
      )
    end
  end

  private class Ticker
    def initialize(@timeout : Float64)
      @abort_timeout = false
      @timeout_channel = Channel(Nil).new
    end

    def receive_select_action
      @timeout_channel.receive_select_action
    end

    def start
      spawn do
        sleep @timeout
        unless @abort_timeout
          @timeout_channel.send nil
        end
      end
    end

    def cancel
      @abort_timeout = true
    end

    def restart
      @abort_timeout = false
      start
    end
  end

  private class WaitGroup
    def initialize
      @count = Atomic(Int32).new(0)
      @span = Time::Span.new(nanoseconds: 5000)
    end

    def add(n = 1)
      @count.add n
    end

    def done
      add(-1)
    end

    def wait
      loop do
        return if @count.get == 0
        sleep(@span)
      end
    end
  end
end
