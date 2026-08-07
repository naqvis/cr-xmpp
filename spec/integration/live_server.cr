require "../spec_helper"

private INTEGRATION_HOST            = ENV["XMPP_INTEGRATION_HOST"]? || "localhost"
private INTEGRATION_PORT            = (ENV["XMPP_INTEGRATION_PORT"]? || "55222").to_i
private INTEGRATION_COMPONENT_PORT  = (ENV["XMPP_INTEGRATION_COMPONENT_PORT"]? || "55535").to_i
private INTEGRATION_CA              = ENV["XMPP_INTEGRATION_CA"]? || "docker/prosody/certs/ca.crt"
private INTEGRATION_DIRECT_TLS_PORT = (ENV["XMPP_DIRECT_TLS_PORT"]? || "5223").to_i
private INTEGRATION_HTTP_PORT       = (ENV["XMPP_INTEGRATION_HTTP_PORT"]? || "55280").to_i

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

# A TCP proxy that forwards the stream verbatim but strips any
# <starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/> element from the
# server's initial <stream:features>, simulating a TLS-stripping attacker
# (RFC 7590 §3.1).
private class StartTLSStrippingProxy
  getter port : Int32

  @server : TCPServer
  @upstream_host : String
  @upstream_port : Int32

  def initialize(@upstream_host, @upstream_port)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.local_address.as(Socket::IPAddress).port
    spawn { accept_connections }
  end

  def close
    @server.close
  end

  private def accept_connections
    loop do
      client = @server.accept
      upstream = TCPSocket.new(@upstream_host, @upstream_port)
      spawn { pump(client, upstream) }
      spawn { strip_and_forward(upstream, client) }
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

  # Forwards upstream->client, removing <starttls/> from the features element.
  private def strip_and_forward(upstream : TCPSocket, client : TCPSocket)
    buffer = IO::Memory.new
    features_seen = false
    chunk = Bytes.new(4096)

    loop do
      count = upstream.read(chunk)
      break if count == 0

      if features_seen
        client.write chunk[0, count]
        next
      end

      buffer.write chunk[0, count]
      data = buffer.to_s
      if close = data.index("</stream:features>")
        features_seen = true
        stripped = data[0, close].gsub(/<starttls\b[^>]*\/>/, "")
        client.write stripped.to_slice
        tail = data[close, data.size - close]
        client.write tail.to_slice
        buffer.clear
      end
    end
  rescue IO::Error
  ensure
    upstream.close unless upstream.closed?
    client.close unless client.closed?
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
  jid : String = "test@localhost/integration",
) : XMPP::Config
  XMPP::Config.new(
    host: INTEGRATION_HOST,
    port: port,
    jid: jid,
    password: "test",
    tls: true,
    tls_ca_certificates: ca_certificates,
    sasl_auth_order: auth_order,
    auto_presence: false,
    io_timeout: 5,
    log_file: log
  )
end

# Direct TLS config: no explicit host so ConnectionResolver consults SRV, with
# direct TLS preferred. The DNS stub in the test points _xmpps-client at the
# exposed direct-TLS port.
private def direct_tls_config(log : IO) : XMPP::Config
  XMPP::Config.new(
    host: "",
    port: INTEGRATION_PORT,
    jid: "test@localhost/direct-tls",
    password: "test",
    tls: true,
    tls_ca_certificates: INTEGRATION_CA,
    auto_presence: false,
    io_timeout: 5,
    log_file: log,
    prefer_direct_tls: true
  )
end

private def websocket_config(log : IO) : XMPP::Config
  XMPP::Config.new(
    host: INTEGRATION_HOST,
    jid: "test@localhost/ws",
    password: "test",
    tls: true,
    tls_ca_certificates: INTEGRATION_CA,
    auto_presence: false,
    io_timeout: 5,
    log_file: log,
    transport: XMPP::TransportMode::WebSocket,
    url: "ws://#{INTEGRATION_HOST}:#{INTEGRATION_HTTP_PORT}/xmpp-websocket"
  )
end

private def bosh_config(log : IO) : XMPP::Config
  XMPP::Config.new(
    host: INTEGRATION_HOST,
    jid: "test@localhost/bosh",
    password: "test",
    tls: true,
    tls_ca_certificates: INTEGRATION_CA,
    auto_presence: false,
    io_timeout: 5,
    log_file: log,
    transport: XMPP::TransportMode::Bosh,
    url: "http://#{INTEGRATION_HOST}:#{INTEGRATION_HTTP_PORT}/http-bind"
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

private def build_publish_iq(node : String, title : String, to : String) : XMPP::Stanza::IQ
  iq = XMPP::Stanza::IQ.new
  iq.type = "set"
  iq.to = to
  pubsub = XMPP::Stanza::PubSub.new
  publish = XMPP::Stanza::Publish.new
  publish.node = node
  item = XMPP::Stanza::Item.new
  item.id = "current"
  tune = XMPP::Stanza::Tune.new
  tune.title = title
  item.tune = tune
  publish.item = item
  pubsub.publish = publish
  iq.payload = pubsub
  iq
end

private def build_subscribe_iq(node : String, jid : String, to : String) : XMPP::Stanza::IQ
  iq = XMPP::Stanza::IQ.new
  iq.type = "set"
  iq.to = to
  pubsub = XMPP::Stanza::PubSub.new
  subscribe = XMPP::Stanza::Subscribe.new
  subscribe.node = node
  subscribe.jid = jid
  pubsub.subscribe = subscribe
  iq.payload = pubsub
  iq
end

private def notification_title(event : XMPP::Stanza::PubSubEvent) : String?
  return nil unless items = event.items
  items.items.first?.try(&.tune).try(&.title)
end

describe "live Prosody interoperability" do
  it "authenticates and binds a server-assigned resource with XEP-0386" do
    wire = IO::Memory.new
    client = XMPP::Client.new(integration_config(wire), XMPP::Router.new)

    begin
      client.connect

      client.bound_jid.should match(/\Atest@localhost\/integration~.+\z/)
      transcript = wire.to_s
      transcript.should match(
        /SEND:\n<authenticate[^>]*xmlns="urn:xmpp:sasl:2"[\s\S]*<bind xmlns="urn:xmpp:bind:0">\s*<tag>integration<\/tag>\s*<\/bind>/
      )
      transcript.should match(/RECV:\n[\s\S]*<bound xmlns=['"]urn:xmpp:bind:0['"]/)
      transcript.should_not match(
        /SEND:\n<iq[^>]*>[\s\S]*?<bind xmlns=['"]urn:ietf:params:xml:ns:xmpp-bind['"]/
      )
    ensure
      client.disconnect
    end
  end

  it "connects, authenticates, and round-trips a ping over WebSocket (RFC 7395)" do
    wire = IO::Memory.new
    client = XMPP::Client.new(websocket_config(wire), XMPP::Router.new)

    begin
      client.connect
      client.bound_jid.should match(/\Atest@localhost\/ws~.+\z/)

      ping = XMPP::Stanza::IQ.new
      ping.type = "get"
      ping.payload = XMPP::Stanza::Ping.new
      client.request(ping).try(&.type).should eq "result"

      transcript = wire.to_s
      transcript.should_not contain("urn:ietf:params:xml:ns:xmpp-tls")
      client.tls_version.should be_nil
      client.cipher.should be_nil
    ensure
      client.disconnect
    end
  end

  it "connects, authenticates, and round-trips a ping over BOSH (XEP-0206)" do
    wire = IO::Memory.new
    client = XMPP::Client.new(bosh_config(wire), XMPP::Router.new)

    begin
      client.connect
      client.bound_jid.should match(/\Atest@localhost\/bosh~.+\z/)

      ping = XMPP::Stanza::IQ.new
      ping.type = "get"
      ping.payload = XMPP::Stanza::Ping.new
      client.request(ping).try(&.type).should eq "result"

      transcript = wire.to_s
      transcript.should_not contain("urn:ietf:params:xml:ns:xmpp-tls")
    ensure
      client.disconnect
    end
  end

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

  it "connects via XEP-0368 direct TLS when SRV prefers it" do
    wire = IO::Memory.new
    port = srv_dns_server(
      [
        {"_xmpps-client._tcp.localhost", 10_u16, 5_u16, INTEGRATION_DIRECT_TLS_PORT.to_u16, "localhost"},
        {"_xmpp-client._tcp.localhost", 10_u16, 5_u16, INTEGRATION_PORT.to_u16, "localhost"},
      ],
      "_xmpp-client._tcp.localhost"
    )
    client = nil.as(XMPP::Client?)

    XMPP::DnsSrv.stub_nameservers ["127.0.0.1:#{port}"] do
      c = XMPP::Client.new(direct_tls_config(wire), XMPP::Router.new)
      client = c
      states = [] of XMPP::ConnectionState
      c.event_handler = ->(event : XMPP::Event) { states << event.state }
      begin
        c.connect
        states.should contain(XMPP::ConnectionState::SessionEstablished)
        c.tls_version.should_not be_nil
        c.cipher.should_not be_nil
        c.tls_verified?.should be_true
        # Direct TLS connects on 5223 and must not perform a STARTTLS upgrade.
        wire.to_s.should_not contain("urn:ietf:params:xml:ns:xmpp-tls")
      ensure
        c.disconnect
      end
    end
  ensure
    client.try(&.disconnect)
  end

  it "negotiates TLS even when STARTTLS is stripped from stream features" do
    proxy = StartTLSStrippingProxy.new(INTEGRATION_HOST, INTEGRATION_PORT)
    wire = IO::Memory.new
    states = connect_and_disconnect(
      integration_config(wire, port: proxy.port)
    )

    states.should contain(XMPP::ConnectionState::SessionEstablished)
    # The server's real features still advertise STARTTLS; only the proxy
    # stripped it. The client must attempt STARTTLS anyway (RFC 7590 §3.1)
    # and the session must be encrypted.
    wire.to_s.should match(/<starttls xmlns=['"]urn:ietf:params:xml:ns:xmpp-tls['"]\/>/)
  ensure
    proxy.try(&.close)
  end

  it "reports TLS introspection on a live encrypted session" do
    wire = IO::Memory.new
    client = XMPP::Client.new(integration_config(wire), XMPP::Router.new)

    begin
      client.connect
      client.tls_version.should_not be_nil
      client.cipher.should_not be_nil
      client.tls_verified?.should be_true
    ensure
      client.disconnect
    end
  end

  it "round-trips a PEP publish/subscribe/notify exchange" do
    node = "http://jabber.org/protocol/tune"

    subscriber_wire = IO::Memory.new
    subscriber, subscriber_router = begin
      router = XMPP::Router.new
      {XMPP::Client.new(
        integration_config(subscriber_wire, jid: "test@localhost/pep-subscriber"),
        router
      ), router}
    end

    publisher_wire = IO::Memory.new
    publisher, publisher_router = begin
      router = XMPP::Router.new
      {XMPP::Client.new(
        integration_config(publisher_wire, jid: "test@localhost/pep-publisher"),
        router
      ), router}
    end

    # Buffered so an early notification cannot stall the subscriber's receive
    # fiber (a blocking send there would starve reading IQ responses).
    event_received = Channel(XMPP::Stanza::PubSubEvent).new(16)
    subscriber_router.message do |_sender, packet|
      next unless packet.is_a?(XMPP::Stanza::Message)
      message = packet.as(XMPP::Stanza::Message)
      if extension = message.get(XMPP::Stanza::PubSubEvent)
        event = extension.as(XMPP::Stanza::PubSubEvent)
        event_received.send(event) unless event_received.closed?
      end
    end

    begin
      subscriber.connect
      publisher.connect

      # Broadcast availability from both resources.
      subscriber.send XMPP::Stanza::Presence.new
      publisher.send XMPP::Stanza::Presence.new
      sleep 200.milliseconds

      # Publisher creates the node implicitly by publishing.
      publisher.request(build_publish_iq(node, "Hey Jude", "test@localhost")).try(&.type).should eq "result"

      # Subscriber subscribes to the publisher's node.
      subscriber.request(build_subscribe_iq(node, "test@localhost", "test@localhost")).try(&.type).should eq "result"

      # Publish again; the subscriber must receive a notification.
      publisher.request(build_publish_iq(node, "Paperback Writer", "test@localhost")).try(&.type).should eq "result"

      # The first publish's notification is delivered to this same-account
      # resource before it subscribes; keep receiving until the notification
      # carrying the newly published item arrives.
      event = nil
      deadline = Time.instant + 5.seconds
      while (remaining = deadline - Time.instant) > Time::Span.zero
        select
        when received = event_received.receive
          if notification_title(received) == "Paperback Writer"
            event = received
            break
          end
        when timeout(remaining)
          break
        end
      end

      event.should_not be_nil
      items = event.not_nil!.items
      items.should_not be_nil
      items.not_nil!.node.should eq node
    ensure
      subscriber.disconnect
      publisher.disconnect
    end
  end

  it "tolerates CSI inactive/active nonzas on a live session" do
    wire = IO::Memory.new
    client = XMPP::Client.new(integration_config(wire), XMPP::Router.new)

    begin
      client.connect
      csi = XMPP::ClientStateIndication.new(client)
      csi.inactive
      csi.active

      # A ping after the nonzas must still get a pong: the server tolerated them.
      ping = XMPP::Stanza::IQ.new
      ping.type = "get"
      ping.payload = XMPP::Stanza::Ping.new
      client.request(ping).try(&.type).should eq "result"

      transcript = wire.to_s
      transcript.should match(/<inactive xmlns="urn:xmpp:csi:0"\/>/)
      transcript.should match(/<active xmlns="urn:xmpp:csi:0"\/>/)
    ensure
      client.disconnect
    end
  end

  it "discovers, enables, and disables push notifications" do
    wire = IO::Memory.new
    client = XMPP::Client.new(integration_config(wire), XMPP::Router.new)

    begin
      client.connect
      push = XMPP::Push.new(client)

      push.supported?.should be_true

      enable_response = push.enable("push-5.client.example", "yxs32uqsflafdk3iuqo")
      enable_response.should_not be_nil
      enable_response.not_nil!.type.should eq "result"

      disable_response = push.disable("push-5.client.example")
      disable_response.should_not be_nil
      disable_response.not_nil!.type.should eq "result"
    ensure
      client.disconnect
    end
  end

  it "stores and retrieves a vCard" do
    wire = IO::Memory.new
    client = XMPP::Client.new(integration_config(wire), XMPP::Router.new)

    begin
      client.connect
      vcard = XMPP::VCard.new(client)

      card = XMPP::Stanza::VCard.new
      card.fn = "Juliet Capulet"
      vcard.set(card).try(&.type).should eq "result"

      fetched = vcard.fetch
      fetched.should_not be_nil
      fetched.not_nil!.fn.should eq "Juliet Capulet"
    ensure
      client.disconnect
    end
  end

  it "delivers a carbon copy of a message sent from another resource" do
    a_router = XMPP::Router.new
    a_wire = IO::Memory.new
    a = XMPP::Client.new(integration_config(a_wire, jid: "test@localhost/carbons-a"), a_router)
    b_wire = IO::Memory.new
    b = XMPP::Client.new(integration_config(b_wire, jid: "test@localhost/carbons-b"), XMPP::Router.new)

    carbon_received = Channel(XMPP::Stanza::CarbonSent).new(16)
    a_router.message do |_sender, packet|
      next unless packet.is_a?(XMPP::Stanza::Message)
      message = packet.as(XMPP::Stanza::Message)
      if extension = message.get(XMPP::Stanza::CarbonSent)
        carbon_received.send(extension.as(XMPP::Stanza::CarbonSent)) unless carbon_received.closed?
      end
    end

    begin
      a.connect
      b.connect
      a.send XMPP::Stanza::Presence.new
      b.send XMPP::Stanza::Presence.new
      sleep 200.milliseconds

      XMPP::Carbons.new(a).supported?.should be_true
      XMPP::Carbons.new(a).enable.try(&.type).should eq "result"

      original = XMPP::Stanza::Message.new
      original.type = "chat"
      original.to = "carlos@localhost"
      original.body = "Hello, world"
      b.send original

      carbon = receive_with_timeout(carbon_received, "carbon copy")
      forwarded = carbon.forwarded.should_not be_nil
      stanza = forwarded.not_nil!.stanza
      stanza.should be_a(XMPP::Stanza::Message)
      stanza.as(XMPP::Stanza::Message).body.should eq "Hello, world"
    ensure
      a.disconnect
      b.disconnect
    end
  end

  it "delivers a direct MUC invitation payload" do
    a_wire = IO::Memory.new
    a = XMPP::Client.new(integration_config(a_wire, jid: "test@localhost/invite-a"), XMPP::Router.new)
    b_router = XMPP::Router.new
    b_wire = IO::Memory.new
    b = XMPP::Client.new(integration_config(b_wire, jid: "test@localhost/invite-b"), b_router)

    invite_received = Channel(XMPP::Stanza::DirectInvite).new(4)
    b_router.message do |_sender, packet|
      next unless packet.is_a?(XMPP::Stanza::Message)
      message = packet.as(XMPP::Stanza::Message)
      if extension = message.get(XMPP::Stanza::DirectInvite)
        invite_received.send(extension.as(XMPP::Stanza::DirectInvite)) unless invite_received.closed?
      end
    end

    begin
      a.connect
      b.connect
      a.send XMPP::Stanza::Presence.new
      b.send XMPP::Stanza::Presence.new
      sleep 200.milliseconds

      XMPP::DirectInvitation.new(a).invite(
        to: b.bound_jid,
        jid: "coven@chat.shakespeare.lit",
        reason: "Hey!"
      )

      invite = receive_with_timeout(invite_received, "direct invite")
      invite.jid.should eq "coven@chat.shakespeare.lit"
      invite.reason.should eq "Hey!"
      invite.thread.should eq ""
    ensure
      a.disconnect
      b.disconnect
    end
  end

  it "uploads and retrieves a file via XEP-0363 HTTP File Upload" do
    wire = IO::Memory.new
    client = XMPP::Client.new(
      integration_config(wire, jid: "test@localhost/http-upload"),
      XMPP::Router.new
    )

    begin
      client.connect
      uploader = XMPP::HTTPUpload.new(client, "upload.localhost")

      uploader.supported?.should be_true

      content = "hello world"
      slot = uploader.request_slot("hello.txt", content.bytesize.to_u64, "text/plain")
      slot.should_not be_nil
      slot = slot.not_nil!
      slot.put_url.should contain("/file_share/")
      slot.get_url.should contain("/file_share/")

      # Prosody 13 serves mod_http_file_share routes on the component's vhost,
      # while the advertised URLs point at upload.localhost:5281 (HTTPS, not
      # mapped in the test harness). Rebase onto the exposed HTTP port and keep
      # the vhost via the Host header so the routes still match.
      rebase = ->(url : String) do
        uri = URI.parse(url)
        uri.scheme = "http"
        uri.host = "127.0.0.1"
        uri.port = INTEGRATION_HTTP_PORT
        uri.to_s
      end
      vhost = URI.parse(slot.put_url).host.not_nil!

      http = HTTP::Client.new("127.0.0.1", INTEGRATION_HTTP_PORT)
      begin
        headers = HTTP::Headers.new
        headers["Host"] = vhost
        slot.put_headers.each { |header| headers[header.name] = header.value }
        headers["Content-Type"] = "text/plain"

        put_target = URI.parse(rebase.call(slot.put_url)).request_target
        put_response = http.put(put_target, headers: headers, body: content)
        put_response.status_code.should eq 201

        get_target = URI.parse(rebase.call(slot.get_url)).request_target
        get_response = http.get(get_target, headers: HTTP::Headers{"Host" => vhost})
        get_response.status_code.should eq 200
        get_response.body.should eq content
      ensure
        http.close
      end
    ensure
      client.disconnect
    end
  end
end
