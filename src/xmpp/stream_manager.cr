require "./event_manager"
require "./xmpp"

module XMPP
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
  class StreamManager
    @client : StreamClient
    @retry_count : Int32
    @post_connect : PostConnect?

    # store low level metrics
    @metrics : Metrics
    @wg : WaitGroup

    def initialize(@client, @retry_count = 5, @post_connect = nil)
      @metrics = Metrics.new
      @wg = WaitGroup.new
    end

    # run launches the connection of the underlying client or component
    # and wait until disconnect is called, or for the manager to terminate due
    # to an unrecoverable exception
    def run : Nil
      @client.event_handler = ->event_handler(Event)
      # @client.event_handler = ->(e : Event) { event_handler e }
      @wg.add(1)
      begin
        connect
      rescue exception
        @wg.done
        raise exception.message || exception # Just send the exception message, not the complete stacktrace
      end
      @wg.wait
    end

    # stop cancels pending operations and terminates existing XMPP client.
    def stop
      # Remove on disconnect handler to avoid triggering reconnect
      @client.event_handler = nil
      @client.disconnect
      @wg.done
    end

    private def connect
      resume(SMState.new)
    end

    # resume manages the reconnection loop and apply the define backoff to avoid overloading the server.
    private def resume(state : SMState)
      attemps = 0
      loop do
        @metrics.reset
        begin
          @client.resume(state)
        rescue ex : AuthenticationError
          Logger.error ex.message
          raise ex
        rescue ex
          # Add some delay to avoid hammering server
          attemps += 1
          if attemps >= @retry_count
            puts "Giving Up after #{@retry_count} tries to connect to server."
            raise ex
          end
          sleep 2.second
        else # We are connected, we can leave the retry loop
          break
        end
      end
      @post_connect.try &.call @client
    end

    private def event_handler(e : Event)
      case e.state
      # when ConnectionState::Connected          then @metrics.set_connect_time
      # when ConnectionState::SessionEstablished then @metrics.set_login_time
      when ConnectionState::Disconnected
        # Reconnect on disconnection
        Logger.info "Client disconnected. Resuming client connection"
        resume(e.sm_state)
      when ConnectionState::StreamError
        @client.disconnect
        # Only try reconnecting if we have not been kicked by another session to avoid connection loop.
        connect unless e.stream_error == "conflict"
      end
    end
  end

  # Stream Metrics
  class Metrics
    @start_time : Time
    # connect_time returns the duration between client initiation of the TCP/IP
    # connection to the server and actual TCP/IP session establishment.
    # This time includes DNS resolution and can be slightly higher if the DNS
    # resolution result was not in cache.
    getter connect_time : Time::Span
    # login_time returns the between client initiation of the TCP/IP
    # connection to the server and the return of the login result.
    # This includes ConnectTime, but also XMPP level protocol negociation
    # like starttls.
    getter login_time : Time::Span

    def initialize
      @start_time = Time.utc
      @connect_time = Time::Span.new(nanoseconds: 0)
      @login_time = Time::Span.new(nanoseconds: 0)
    end

    def reset
      @start_time = Time.utc
      @connect_time = Time::Span.new(nanoseconds: 0)
      @login_time = Time::Span.new(nanoseconds: 0)
    end

    def set_connect_time
      @connect_time = Time.utc - @start_time
    end

    def set_login_time
      @login_time = Time.utc - @start_time
    end
  end
end
