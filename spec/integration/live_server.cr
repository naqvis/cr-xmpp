require "../spec_helper"

private INTEGRATION_HOST           = ENV["XMPP_INTEGRATION_HOST"]? || "localhost"
private INTEGRATION_PORT           = (ENV["XMPP_INTEGRATION_PORT"]? || "55222").to_i
private INTEGRATION_COMPONENT_PORT = (ENV["XMPP_INTEGRATION_COMPONENT_PORT"]? || "55535").to_i
private INTEGRATION_CA             = ENV["XMPP_INTEGRATION_CA"]? || "docker/prosody/certs/ca.crt"

private class DisconnectingProxy
  getter port : Int32

  @server : TCPServer
  @upstream_host : String
  @upstream_port : Int32
  @mutex = Mutex.new
  @current : Tuple(TCPSocket, TCPSocket)? = nil
  @closed = false

  def initialize(@upstream_host, @upstream_port)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.local_address.as(Socket::IPAddress).port
    spawn { accept_connections }
  end

  def cut
    pair = @mutex.synchronize do
      current = @current
      @current = nil
      current
    end
    close_pair(pair)
  end

  def close
    should_close = @mutex.synchronize do
      next false if @closed
      @closed = true
      true
    end
    return unless should_close

    @server.close
    cut
  end

  private def accept_connections
    loop do
      client = @server.accept
      upstream = TCPSocket.new(@upstream_host, @upstream_port)
      @mutex.synchronize { @current = {client, upstream} }
      spawn { pump(client, upstream) }
      spawn { pump(upstream, client) }
    end
  rescue IO::Error
    # Closing the listener terminates the accept loop.
  end

  private def pump(source : TCPSocket, destination : TCPSocket)
    IO.copy(source, destination)
  rescue IO::Error
  ensure
    source.close unless source.closed?
    destination.close unless destination.closed?
  end

  private def close_pair(pair : Tuple(TCPSocket, TCPSocket)?)
    return unless pair
    pair.each { |socket| socket.close unless socket.closed? }
  end
end

private def receive_with_timeout(channel : Channel(T), description : String, timeout_seconds = 15) : T forall T
  select
  when value = channel.receive
    value
  when timeout(timeout_seconds.seconds)
    raise "timed out waiting for #{description}"
  end
end

private def integration_config(
  log : IO,
  auth_order = XMPP::SASL_AUTH_ORDER,
  ca_certificates : String? = INTEGRATION_CA,
  port : Int32 = INTEGRATION_PORT,
) : XMPP::Config
  XMPP::Config.new(
    host: INTEGRATION_HOST,
    port: port,
    jid: "test@localhost/integration",
    password: "test",
    tls: true,
    tls_ca_certificates: ca_certificates,
    sasl_auth_order: auth_order,
    auto_presence: false,
    io_timeout: 5,
    log_file: log
  )
end

private def connect_and_disconnect(config : XMPP::Config) : Array(XMPP::ConnectionState)
  states = [] of XMPP::ConnectionState
  client = XMPP::Client.new(config, XMPP::Router.new)
  client.event_handler = ->(event : XMPP::Event) { states << event.state }

  begin
    client.connect
    client.send("<presence/>")
  ensure
    client.disconnect
  end
  states
end

describe "live Prosody interoperability" do
  it "establishes a certificate-verified TLS and SCRAM session" do
    wire = IO::Memory.new
    states = connect_and_disconnect(integration_config(wire))

    states.should contain(XMPP::ConnectionState::Connected)
    states.should contain(XMPP::ConnectionState::SessionEstablished)
    wire.to_s.should match(/mechanism="SCRAM-SHA-(?:512|256|1)(?:-PLUS)?"/)
  end

  it "supports explicitly enabled PLAIN only with verified TLS" do
    wire = IO::Memory.new
    states = connect_and_disconnect(
      integration_config(wire, [XMPP::AuthMechanism::PLAIN])
    )

    states.should contain(XMPP::ConnectionState::SessionEstablished)
    wire.to_s.should contain("mechanism=\"PLAIN\"")
  end

  it "rejects the server when its private test CA is not trusted" do
    config = integration_config(IO::Memory.new, ca_certificates: nil)
    client = XMPP::Client.new(config, XMPP::Router.new)

    error = expect_raises(XMPP::TLSVerificationError) { client.connect }
    error.retryable?.should be_false
  ensure
    client.try(&.disconnect)
  end

  it "resumes an XEP-0198 session after an abrupt transport failure" do
    proxy = DisconnectingProxy.new(INTEGRATION_HOST, INTEGRATION_PORT)
    wire = IO::Memory.new
    client = XMPP::Client.new(
      integration_config(wire, port: proxy.port),
      XMPP::Router.new
    )
    connected = Channel(Nil).new(2)
    result = Channel(Exception?).new(1)
    manager = XMPP::StreamManager.new(
      client,
      reconnect_policy: XMPP::ReconnectPolicy.new(
        initial_delay: 10.milliseconds,
        max_delay: 50.milliseconds,
        jitter: 0.0
      ),
      post_connect: ->(_sender : XMPP::Sender) { connected.send(nil) }
    )

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

    receive_with_timeout(connected, "initial managed connection")
    client.session.sm_state.id.should_not be_empty
    client.send("<presence id='before-cut'/>")

    proxy.cut
    receive_with_timeout(connected, "resumed managed connection")

    wire.to_s.should match(/<resume xmlns=['"]urn:xmpp:sm:3['"]/)
    manager.metrics.reconnect_attempts.should be >= 1
    manager.metrics.successful_connections.should eq 2
    manager.metrics.resumption_attempts.should eq 1
    manager.metrics.resumption_successes.should eq 1
    manager.metrics.resumption_failures.should eq 0
  ensure
    manager.try(&.stop)
    proxy.try(&.close)
    if result
      receive_with_timeout(result, "stream manager shutdown").should be_nil
    end
  end

  it "connects and authenticates a real external component" do
    states = [] of XMPP::ConnectionState
    component = XMPP::Component.new(
      XMPP::ComponentOptions.new(
        domain: "component.localhost",
        secret: "component-secret",
        host: INTEGRATION_HOST,
        port: INTEGRATION_COMPONENT_PORT,
        name: "integration component",
        category: "component",
        type: "generic"
      ),
      XMPP::Router.new
    )
    component.event_handler = ->(event : XMPP::Event) { states << event.state }

    begin
      component.connect
      component.send("<presence from='component.localhost' to='localhost'/>")
      component.current_state.should eq XMPP::ConnectionState::SessionEstablished
    ensure
      component.disconnect
    end

    states.should contain(XMPP::ConnectionState::Connected)
    states.should contain(XMPP::ConnectionState::SessionEstablished)
    states.count(XMPP::ConnectionState::Disconnected).should eq 1
  end

  it "returns a permanent typed error for an invalid component secret" do
    component = XMPP::Component.new(
      XMPP::ComponentOptions.new(
        domain: "component.localhost",
        secret: "wrong-secret",
        host: INTEGRATION_HOST,
        port: INTEGRATION_COMPONENT_PORT,
        name: "invalid integration component",
        category: "component",
        type: "generic"
      ),
      XMPP::Router.new
    )

    error = expect_raises(XMPP::ComponentAuthenticationError) { component.connect }
    error.retryable?.should be_false
  ensure
    component.try(&.disconnect)
  end

  it "serializes concurrent writes and disconnects idempotently" do
    wire = IO::Memory.new
    events = [] of XMPP::Event
    client = XMPP::Client.new(integration_config(wire), XMPP::Router.new)
    client.event_handler = ->(event : XMPP::Event) { events << event }
    fiber_count = 10
    messages_per_fiber = 8
    completed = Channel(Exception?).new(fiber_count)

    begin
      client.connect
      fiber_count.times do |fiber|
        spawn do
          error = nil.as(Exception?)
          begin
            messages_per_fiber.times do |message|
              client.send("<presence id='concurrent-#{fiber}-#{message}'/>")
            end
          rescue ex
            error = ex
          ensure
            completed.send(error)
          end
        end
      end

      fiber_count.times do
        if error = completed.receive
          raise error
        end
      end

      # Give Prosody a chance to reject malformed/interleaved XML if writes were
      # not serialized.
      sleep 100.milliseconds
      disconnect = events.reverse.find(&.state.disconnected?)
      if disconnect
        raise disconnect.exception || disconnect.description
      end
      client.current_state.should eq XMPP::ConnectionState::SessionEstablished
    ensure
      client.disconnect
      client.disconnect
    end

    events.count(&.state.disconnected?).should eq 1
    wire.to_s.scan(/<presence id='concurrent-\d+-\d+'\/>/).size.should eq(
      fiber_count * messages_per_fiber
    )
  end
end
