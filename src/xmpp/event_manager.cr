require "./xmpp"

module XMPP
  # Event Manager
  # EventHandler is use to pass events about state of the connection to
  # client implementation.
  alias EventHandler = (Event) ->

  # Base error for failures in the XMPP connection lifecycle.
  class ConnectionError < Exception
    def retryable? : Bool
      true
    end
  end

  # Repeating the connection with unchanged configuration or credentials will
  # not resolve this failure.
  class PermanentConnectionError < ConnectionError
    def retryable? : Bool
      false
    end
  end

  class ConnectionClosed < ConnectionError; end

  class AlreadyConnectedError < ConnectionError; end

  class NotConnectedError < ConnectionError; end

  class SendQueueFullError < ConnectionError; end

  class ProtocolError < PermanentConnectionError; end

  class StreamManagementError < ProtocolError; end

  class TLSNegotiationError < ConnectionError; end

  class TLSVerificationError < PermanentConnectionError; end

  class TLSUnavailableError < PermanentConnectionError; end

  class ConfigurationError < ArgumentError; end

  # ConnectionState represents the current connection state.
  # This is a list of events happening on the connection that
  # the client can be notified about.
  enum ConnectionState
    Disconnected
    Connected
    SessionEstablished
    StreamError
    Connecting
    Disconnecting
  end

  # SMState holds Stream Management information regarding the session that can be
  # used to resume session after disconnect
  class SMState
    property id : String                                 # Stream Management ID
    property inbound : UInt32                            # Inbound stanza count
    property outbound : UInt32                           # Outbound stanza count (sent by us)
    property location : String                           # Server location for IP affinity (XEP-0198)
    property max : UInt32                                # Maximum resumption time in seconds
    property timestamp : Time                            # When this state was created/last updated
    property error : String                              # Last error message if SM failed
    @unacked_stanzas : Array(String) = Array(String).new # Queue of unacknowledged stanzas
    @mutex = Mutex.new

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
    def queue_stanza(stanza : String, max_size : Int32? = nil)
      @mutex.synchronize do
        if max_size && @unacked_stanzas.size >= max_size
          raise SendQueueFullError.new(
            "stream-management queue is full (#{max_size} unacknowledged stanzas)"
          )
        end
        @unacked_stanzas << stanza
        @outbound &+= 1_u32
      end
    end

    # Process acknowledgement from server
    # Server sends the count of stanzas it has received
    def process_ack(h : UInt32)
      @mutex.synchronize do
        # XEP-0198 counters wrap modulo 2^32. The oldest queued stanza follows
        # the last acknowledged sequence number.
        last_acknowledged = @outbound &- @unacked_stanzas.size.to_u32
        acked_count = h &- last_acknowledged
        if acked_count > @unacked_stanzas.size
          raise StreamManagementError.new(
            "invalid stream-management acknowledgement h=#{h}; " \
            "#{@unacked_stanzas.size} stanza(s) are outstanding"
          )
        end

        if acked_count > 0
          @unacked_stanzas.shift(acked_count.to_i)
          Logger.debug "Acknowledged #{acked_count} stanzas, #{@unacked_stanzas.size} remaining in queue"
        end
      end
    end

    # Return a snapshot so callers cannot mutate the queue without synchronization.
    def unacked_stanzas : Array(String)
      @mutex.synchronize { @unacked_stanzas.dup }
    end

    def unacked_count : Int32
      @mutex.synchronize { @unacked_stanzas.size }
    end

    # Get stanzas that need to be resent
    def stanzas_to_resend : Array(String)
      unacked_stanzas
    end

    # Clear the unacknowledged queue (after successful resend)
    def clear_queue
      @mutex.synchronize { @unacked_stanzas.clear }
    end

    # Check if we have unacknowledged stanzas
    def has_unacked_stanzas? : Bool
      @mutex.synchronize { !@unacked_stanzas.empty? }
    end
  end

  # Event is a structure use to convey event changes related to client state. This
  # is for example used to notify the client when the client get disconnected.

  struct Event
    property state : ConnectionState
    property description : String
    property stream_error : String
    property sm_state : SMState
    property exception : Exception?

    def initialize(@state = ConnectionState::Disconnected,
                   @description = "", @stream_error = "",
                   @sm_state = SMState.new, @exception = nil)
    end
  end

  module EventManager
    # Store current state
    @current_state : ConnectionState = ConnectionState::Disconnected
    # Callback used to propagate connection state changes
    @event_handler : EventHandler? = nil
    @event_mutex = Mutex.new

    def event_handler=(handler : EventHandler?)
      @event_mutex.synchronize { @event_handler = handler }
    end

    def event_handler : EventHandler?
      @event_mutex.synchronize { @event_handler }
    end

    def current_state : ConnectionState
      @event_mutex.synchronize { @current_state }
    end

    private def set_current_state(state : ConnectionState)
      @event_mutex.synchronize { @current_state = state }
    end

    private def update_state(state : ConnectionState)
      handler = @event_mutex.synchronize do
        @current_state = state
        @event_handler
      end
      handler.try &.call Event.new(state: state)
    end

    private def disconnected(state : SMState, exception : Exception? = nil)
      handler = @event_mutex.synchronize do
        @current_state = ConnectionState::Disconnected
        @event_handler
      end
      handler.try &.call Event.new(
        state: ConnectionState::Disconnected,
        description: exception.try(&.message) || "",
        sm_state: state,
        exception: exception)
    end

    private def stream_error(error : String, desc : String)
      handler = @event_mutex.synchronize do
        @current_state = ConnectionState::StreamError
        @event_handler
      end
      handler.try &.call Event.new(
        state: ConnectionState::StreamError,
        stream_error: error,
        description: desc
      )
    end
  end
end
