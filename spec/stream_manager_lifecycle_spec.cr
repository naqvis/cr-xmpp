require "./spec_helper"

private class LifecycleStreamClient
  include XMPP::StreamClient
  include XMPP::EventManager
  getter resume_calls = Channel(XMPP::SMState).new(4)
  getter disconnect_count = Atomic(Int32).new(0)

  def connect
    resume(XMPP::SMState.new)
  end

  def resume(state : XMPP::SMState)
    @resume_calls.send(state)
  end

  def disconnect
    @disconnect_count.add(1)
  end

  def send(packet : XMPP::Stanza::Packet)
  end

  def send(packet : String)
  end

  def emit(event : XMPP::Event)
    @event_handler.try &.call(event)
  end
end

private class RetryingStreamClient
  include XMPP::StreamClient
  include XMPP::EventManager

  getter attempts = Atomic(Int32).new(0)
  getter attempted = Channel(Int32).new(8)
  getter disconnect_count = Atomic(Int32).new(0)

  def initialize(@failures_before_success : Int32, @failure : Exception = IO::Error.new("temporary outage"))
  end

  def connect
    resume(XMPP::SMState.new)
  end

  def resume(state : XMPP::SMState)
    attempt = @attempts.add(1) + 1
    @attempted.send(attempt)
    raise @failure if attempt <= @failures_before_success
  end

  def disconnect
    @disconnect_count.add(1)
  end

  def send(packet : XMPP::Stanza::Packet)
  end

  def send(packet : String)
  end
end

private def next_resume(client : LifecycleStreamClient) : XMPP::SMState
  select
  when state = client.resume_calls.receive
    state
  when timeout(1.second)
    raise "timed out waiting for StreamManager resume"
  end
end

describe XMPP::StreamManager do
  it "calculates bounded exponential reconnect delays with deterministic jitter" do
    policy = XMPP::ReconnectPolicy.new(
      initial_delay: 1.second,
      max_delay: 5.seconds,
      multiplier: 2.0,
      jitter: 0.2
    )

    policy.delay_for(1, 0.5).should eq 1.second
    policy.delay_for(2, 0.5).should eq 2.seconds
    policy.delay_for(3, 0.5).should eq 4.seconds
    policy.delay_for(4, 0.5).should eq 5.seconds
    policy.delay_for(2, 0.0).should eq 1.6.seconds
    policy.delay_for(2, 1.0).should eq 2.4.seconds
  end

  it "validates reconnect policy and retry configuration" do
    expect_raises(XMPP::ConfigurationError, /initial_delay/) do
      XMPP::ReconnectPolicy.new(initial_delay: 0.seconds)
    end
    expect_raises(XMPP::ConfigurationError, /max_delay/) do
      XMPP::ReconnectPolicy.new(initial_delay: 2.seconds, max_delay: 1.second)
    end
    expect_raises(XMPP::ConfigurationError, /multiplier/) do
      XMPP::ReconnectPolicy.new(multiplier: 0.5)
    end
    expect_raises(XMPP::ConfigurationError, /jitter/) do
      XMPP::ReconnectPolicy.new(jitter: 1.1)
    end

    expect_raises(XMPP::ConfigurationError, /retry_count/) do
      XMPP::StreamManager.new(LifecycleStreamClient.new, retry_count: 0)
    end
  end

  it "retries transient failures with backoff and records metrics" do
    client = RetryingStreamClient.new(failures_before_success: 2)
    policy = XMPP::ReconnectPolicy.new(
      initial_delay: 1.millisecond,
      max_delay: 2.milliseconds,
      jitter: 0.0
    )
    manager = XMPP::StreamManager.new(client, retry_count: 3, reconnect_policy: policy)
    result = Channel(Exception?).new(1)

    spawn do
      error = nil.as(Exception?)
      begin
        manager.run
      rescue ex
        error = ex
      ensure
        result.send(error)
      end
    end

    3.times { client.attempted.receive }
    manager.stop

    result.receive.should be_nil
    manager.metrics.connection_attempts.should eq 3
    manager.metrics.reconnect_attempts.should eq 2
    manager.metrics.failed_attempts.should eq 2
    manager.metrics.successful_connections.should eq 1
    manager.metrics.last_error.should be_nil
  end

  it "does not retry permanent authentication failures" do
    client = RetryingStreamClient.new(
      failures_before_success: 3,
      failure: XMPP::AuthenticationError.new("bad credentials")
    )
    manager = XMPP::StreamManager.new(
      client,
      retry_count: 3,
      reconnect_policy: XMPP::ReconnectPolicy.new(
        initial_delay: 1.millisecond,
        max_delay: 1.millisecond,
        jitter: 0.0
      )
    )

    expect_raises(XMPP::AuthenticationError, "bad credentials") { manager.run }
    client.attempts.get.should eq 1
    manager.metrics.connection_attempts.should eq 1
    manager.metrics.failed_attempts.should eq 1
    manager.metrics.last_error.should eq "bad credentials"
  end

  it "does not reconnect after a permanent receiver failure" do
    client = LifecycleStreamClient.new
    manager = XMPP::StreamManager.new(
      client,
      reconnect_policy: XMPP::ReconnectPolicy.new(
        initial_delay: 1.millisecond,
        max_delay: 1.millisecond,
        jitter: 0.0
      )
    )
    result = Channel(Exception?).new(1)

    spawn do
      error = nil.as(Exception?)
      begin
        manager.run
      rescue ex
        error = ex
      ensure
        result.send(error)
      end
    end

    next_resume(client)
    failure = XMPP::StreamParseError.new("malformed server stream")
    client.emit(XMPP::Event.new(
      state: XMPP::ConnectionState::Disconnected,
      description: failure.message || "",
      exception: failure
    ))

    receive_error = select
    when error = result.receive
      error
    when timeout(1.second)
      raise "timed out waiting for permanent receiver failure"
    end
    receive_error.should be_a(XMPP::StreamParseError)
    select
    when client.resume_calls.receive
      raise "StreamManager retried a permanent receiver failure"
    when timeout(10.milliseconds)
    end
    manager.metrics.disconnects.should eq 1
    manager.metrics.last_error.should eq "malformed server stream"
  end

  it "reports queue depth and resumption outcomes without exposing mutable state" do
    depth = Atomic(Int32).new(3)
    metrics = XMPP::Metrics.new(-> { depth.get })

    metrics.start_attempt(reconnect: true, resumption: true)
    metrics.record_success(resumed: true)
    metrics.stream_management_queue_depth.should eq 3
    metrics.resumption_attempts.should eq 1
    metrics.resumption_successes.should eq 1
    metrics.resumption_failures.should eq 0

    depth.set(1)
    metrics.stream_management_queue_depth.should eq 1
    metrics.start_attempt(reconnect: true, resumption: true)
    metrics.record_success(resumed: false)
    metrics.resumption_attempts.should eq 2
    metrics.resumption_successes.should eq 1
    metrics.resumption_failures.should eq 1
  end

  it "reconnects outside the event callback and stops idempotently" do
    client = LifecycleStreamClient.new
    manager = XMPP::StreamManager.new(client)
    result = Channel(Exception?).new(1)

    spawn do
      error = nil.as(Exception?)
      begin
        manager.run
      rescue ex
        error = ex
      ensure
        result.send(error)
      end
    end

    next_resume(client) # Initial connection.
    client.emit(XMPP::Event.new(state: XMPP::ConnectionState::Connected))
    client.emit(XMPP::Event.new(state: XMPP::ConnectionState::SessionEstablished))
    resumable = XMPP::SMState.new(id: "resume-me")
    client.emit(XMPP::Event.new(
      state: XMPP::ConnectionState::Disconnected,
      sm_state: resumable
    ))

    next_resume(client).same?(resumable).should be_true
    manager.stop
    manager.stop

    select
    when error = result.receive
      error.should be_nil
    when timeout(1.second)
      raise "timed out waiting for StreamManager to stop"
    end
    client.disconnect_count.get.should eq 1
    manager.metrics.connection_attempts.should eq 2
    manager.metrics.reconnect_attempts.should eq 1
    manager.metrics.successful_connections.should eq 2
    manager.metrics.disconnects.should eq 1
    manager.metrics.resumption_attempts.should eq 1
    manager.metrics.resumption_successes.should eq 0
    manager.metrics.resumption_failures.should eq 1
    manager.metrics.connect_time.should be >= 0.seconds
    manager.metrics.login_time.should be >= 0.seconds
  end
end
