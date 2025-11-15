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
  class SMState
    property id : String                                         # Stream Management ID
    property inbound : UInt32                                    # Inbound stanza count
    property outbound : UInt32                                   # Outbound stanza count (sent by us)
    property location : String                                   # Server location for IP affinity (XEP-0198)
    property max : UInt32                                        # Maximum resumption time in seconds
    property timestamp : Time                                    # When this state was created/last updated
    property error : String                                      # Last error message if SM failed
    property unacked_stanzas : Array(String) = Array(String).new # Queue of unacknowledged stanzas

    def initialize(@id = "", @inbound = 0_u32, @outbound = 0_u32, @location = "",
                   @max = 0_u32, @timestamp = Time.utc, @error = "")
    end

    # Check if resumption should be attempted based on max time
    def resumption_expired? : Bool
      return false if max == 0 # No expiration set
      (Time.utc - timestamp).total_seconds > max
    end

    # Check if this state is valid for resumption
    def can_resume? : Bool
      !id.blank? && !resumption_expired?
    end

    # Update timestamp to current time
    def touch
      @timestamp = Time.utc
    end

    # Add a stanza to the unacknowledged queue
    def queue_stanza(stanza : String)
      @unacked_stanzas << stanza
      @outbound += 1
    end

    # Process acknowledgement from server
    # Server sends the count of stanzas it has received
    def process_ack(h : UInt32)
      # h is the number of stanzas the server has received
      # Calculate how many stanzas we can remove from queue
      acked_count = h - (outbound - unacked_stanzas.size.to_u32)

      if acked_count > 0 && acked_count <= unacked_stanzas.size
        # Remove acknowledged stanzas from the front of the queue
        @unacked_stanzas.shift(acked_count.to_i)
        Logger.debug "Acknowledged #{acked_count} stanzas, #{@unacked_stanzas.size} remaining in queue"
      end
    end

    # Get stanzas that need to be resent
    def stanzas_to_resend : Array(String)
      @unacked_stanzas.dup
    end

    # Clear the unacknowledged queue (after successful resend)
    def clear_queue
      @unacked_stanzas.clear
    end

    # Check if we have unacknowledged stanzas
    def has_unacked_stanzas? : Bool
      !@unacked_stanzas.empty?
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
    @event_handler : EventHandler? = nil

    def event_handler=(handler : EventHandler?)
      @event_handler = handler
    end

    def event_handler : EventHandler?
      @event_handler
    end

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
        sleep @timeout.seconds
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
      @chan = Channel(Nil).new
    end

    def add(n = 1)
      return @count.get if n == 0
      count = @count.add(n) + n # New value
      @chan.close if count <= 0
      count
    end

    def count
      @count.get
    end

    def done
      add(-1)
    end

    def done?
      @chan.closed?
    end

    def wait
      return if @count.get == 0 # Don't block when first constructed
      @chan.receive
    rescue Channel::ClosedError
    end
  end
end
