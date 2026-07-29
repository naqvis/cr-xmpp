require "./event_manager"
require "./xmpp"

module XMPP
  # Exponential reconnect timing with bounded symmetric jitter.
  #
  # `delay_for` uses a one-based retry number: retry 1 waits `initial_delay`,
  # retry 2 waits `initial_delay * multiplier`, up to `max_delay`.
  struct ReconnectPolicy
    getter initial_delay : Time::Span
    getter max_delay : Time::Span
    getter multiplier : Float64
    getter jitter : Float64

    def initialize(
      @initial_delay = 1.second,
      @max_delay = 30.seconds,
      @multiplier = 2.0,
      @jitter = 0.2,
    )
      raise ConfigurationError.new("initial_delay must be positive") unless @initial_delay.total_nanoseconds > 0
      raise ConfigurationError.new("max_delay must be at least initial_delay") unless @max_delay >= @initial_delay
      raise ConfigurationError.new("multiplier must be at least 1.0") unless @multiplier >= 1.0
      raise ConfigurationError.new("jitter must be between 0.0 and 1.0") unless @jitter.in?(0.0..1.0)
    end

    def delay_for(retry_number : Int32, jitter_sample : Float64 = Random.rand) : Time::Span
      raise ArgumentError.new("retry_number must be positive") unless retry_number > 0
      raise ArgumentError.new("jitter_sample must be between 0.0 and 1.0") unless jitter_sample.in?(0.0..1.0)

      delay = @initial_delay.total_seconds
      maximum = @max_delay.total_seconds
      (retry_number - 1).times do
        delay = Math.min(delay * @multiplier, maximum)
      end

      jitter_factor = 1.0 + ((jitter_sample * 2.0 - 1.0) * @jitter)
      Math.min(delay * jitter_factor, maximum).seconds
    end
  end

  # The Crystal XMPP shard can manage client or component XMPP streams.
  # The StreamManager handles the stream workflow handling the common
  # stream events and doing the right operations.
  #
  # It can handle:
  #     - Client
  #     - Stream establishment workflow
  #     - Reconnection strategies, with exponential backoff. It also takes into account
  #       permanent errors to avoid useless reconnection loops.
  #     - Metrics processing

  alias PostConnect = (Sender) ->

  # StreamManager supervises an XMPP client connection. Its role is to handle connection events and
  # apply reconnection strategy.
  class StreamManager(T)
    @client : T
    @retry_count : Int32
    @post_connect : PostConnect?

    getter metrics : Metrics
    getter reconnect_policy : ReconnectPolicy
    @mutex = Mutex.new
    @done = Channel(Nil).new
    @terminal_error : Exception? = nil
    @running = false
    @stopping = false
    @reconnecting = false

    def initialize(
      @client : T,
      @retry_count = 5,
      @post_connect = nil,
      @reconnect_policy = ReconnectPolicy.new,
    )
      raise ConfigurationError.new("retry_count must be positive") unless @retry_count > 0
      @metrics = Metrics.new(-> { @client.unacknowledged_stanza_count })
    end

    # run launches the connection of the underlying client or component
    # and wait until disconnect is called, or for the manager to terminate due
    # to an unrecoverable exception
    def run : Nil
      @mutex.synchronize do
        raise ConnectionError.new("stream manager is already running") if @running
        @running = true
      end
      @client.event_handler = ->(event : Event) { event_handler(event) }
      begin
        connect
      rescue exception
        finish
        raise exception
      end

      @done.receive?
      if exception = @mutex.synchronize { @terminal_error }
        raise exception
      end
    end

    # stop cancels pending operations and terminates existing XMPP client.
    def stop
      should_stop = @mutex.synchronize do
        next false if @stopping
        @stopping = true
        true
      end
      return unless should_stop

      @client.event_handler = nil # Avoid triggering reconnect.
      @client.disconnect
      finish
    end

    private def connect
      resume(SMState.new, reconnect: false)
    end

    # Resume manages the reconnection loop and applies bounded exponential
    # backoff with jitter to avoid synchronized reconnect storms.
    private def resume(state : SMState, reconnect : Bool)
      failures = 0
      loop do
        return if stopping?
        @metrics.start_attempt(reconnect || failures > 0, state.can_resume?)
        begin
          @client.resume(state)
        rescue ex
          @metrics.record_failure(ex)
          unless retryable?(ex)
            Logger.error "Permanent connection failure: #{ex.message}"
            raise ex
          end

          failures += 1
          if failures >= @retry_count
            Logger.error "Giving up after #{@retry_count} tries to connect to server"
            raise ex
          end

          delay = @reconnect_policy.delay_for(failures)
          Logger.warn "Connection attempt failed; retrying in #{delay.total_seconds.round(3)}s: #{ex.message}"
          select
          when @done.receive?
            return
          when timeout(delay)
          end
        else
          @metrics.record_success(@client.last_resume_succeeded?)
          break
        end
      end
      @post_connect.try &.call @client unless stopping?
    end

    private def event_handler(e : Event)
      case e.state
      when ConnectionState::Connected
        @metrics.record_connected
      when ConnectionState::SessionEstablished
        @metrics.record_session_established
      when ConnectionState::Disconnected
        @metrics.record_disconnected(e)
        if exception = e.exception
          unless retryable?(exception)
            finish(exception)
            return
          end
        end
        schedule_reconnect(e.sm_state)
      when ConnectionState::StreamError
        @metrics.record_stream_error(e)
        # Only try reconnecting if we have not been kicked by another session to avoid connection loop.
        if e.stream_error == "conflict"
          spawn do
            @client.event_handler = nil
            @client.disconnect
            finish
          end
        else
          schedule_reconnect(SMState.new, disconnect_first: true)
        end
      end
    end

    private def schedule_reconnect(state : SMState, disconnect_first = false)
      should_start = @mutex.synchronize do
        next false if @stopping || @reconnecting
        @reconnecting = true
        true
      end
      return unless should_start

      Logger.info "Client disconnected. Resuming client connection"
      spawn do
        begin
          @client.disconnect if disconnect_first
          resume(state, reconnect: true)
        rescue ex
          finish(ex)
        ensure
          @mutex.synchronize { @reconnecting = false }
        end
      end
    end

    private def stopping? : Bool
      @mutex.synchronize { @stopping }
    end

    private def retryable?(exception : Exception) : Bool
      return exception.retryable? if exception.is_a?(ConnectionError)
      !exception.is_a?(ArgumentError)
    end

    private def finish(exception : Exception? = nil)
      @mutex.synchronize do
        @terminal_error ||= exception
        @stopping = true
        @running = false
        @done.close unless @done.closed?
      end
      @client.event_handler = nil
    end
  end

  # Thread-safe operational metrics for a managed XMPP stream.
  class Metrics
    @mutex = Mutex.new
    @attempt_started_at : Time
    @connect_time : Time::Span
    @login_time : Time::Span
    @connection_attempts = 0
    @reconnect_attempts = 0
    @successful_connections = 0
    @failed_attempts = 0
    @disconnects = 0
    @stream_errors = 0
    @resumption_attempts = 0
    @resumption_successes = 0
    @resumption_failures = 0
    @resumption_pending = false
    @last_error : String? = nil
    @last_stream_error : String? = nil

    def initialize(@queue_depth : -> Int32 = -> { 0 })
      @attempt_started_at = Time.utc
      @connect_time = 0.seconds
      @login_time = 0.seconds
    end

    # Reset timing values while retaining cumulative counters.
    def reset
      @mutex.synchronize do
        @attempt_started_at = Time.utc
        @connect_time = 0.seconds
        @login_time = 0.seconds
      end
    end

    def start_attempt(reconnect : Bool, resumption : Bool = false)
      @mutex.synchronize do
        @attempt_started_at = Time.utc
        @connect_time = 0.seconds
        @login_time = 0.seconds
        @connection_attempts += 1
        @reconnect_attempts += 1 if reconnect
        @resumption_attempts += 1 if resumption
        @resumption_pending = resumption
      end
    end

    def record_connected
      @mutex.synchronize { @connect_time = Time.utc - @attempt_started_at }
    end

    def record_session_established
      @mutex.synchronize { @login_time = Time.utc - @attempt_started_at }
    end

    def record_success(resumed : Bool = false)
      @mutex.synchronize do
        @successful_connections += 1
        @resumption_successes += 1 if resumed
        @resumption_failures += 1 if @resumption_pending && !resumed
        @resumption_pending = false
        @last_error = nil
      end
    end

    def record_failure(exception : Exception)
      @mutex.synchronize do
        @failed_attempts += 1
        @resumption_failures += 1 if @resumption_pending
        @resumption_pending = false
        @last_error = exception.message
      end
    end

    def record_disconnected(event : Event)
      @mutex.synchronize do
        @disconnects += 1
        @last_error = event.description unless event.description.blank?
      end
    end

    def record_stream_error(event : Event)
      @mutex.synchronize do
        @stream_errors += 1
        @last_stream_error = event.stream_error
      end
    end

    def connect_time : Time::Span
      @mutex.synchronize { @connect_time }
    end

    def login_time : Time::Span
      @mutex.synchronize { @login_time }
    end

    def connection_attempts : Int32
      @mutex.synchronize { @connection_attempts }
    end

    def reconnect_attempts : Int32
      @mutex.synchronize { @reconnect_attempts }
    end

    def successful_connections : Int32
      @mutex.synchronize { @successful_connections }
    end

    def failed_attempts : Int32
      @mutex.synchronize { @failed_attempts }
    end

    def disconnects : Int32
      @mutex.synchronize { @disconnects }
    end

    def stream_errors : Int32
      @mutex.synchronize { @stream_errors }
    end

    def resumption_attempts : Int32
      @mutex.synchronize { @resumption_attempts }
    end

    def resumption_successes : Int32
      @mutex.synchronize { @resumption_successes }
    end

    def resumption_failures : Int32
      @mutex.synchronize { @resumption_failures }
    end

    def stream_management_queue_depth : Int32
      @queue_depth.call
    end

    def last_error : String?
      @mutex.synchronize { @last_error }
    end

    def last_stream_error : String?
      @mutex.synchronize { @last_stream_error }
    end
  end
end
