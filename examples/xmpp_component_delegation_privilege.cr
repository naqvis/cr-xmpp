require "../src/cr-xmpp"

# Example: XMPP Component with Delegation and Privilege Support
# This demonstrates XEP-0355 (Namespace Delegation) and XEP-0356 (Privileged Entity)

# Component configuration
options = XMPP::ComponentOptions.new(
  domain: "pubsub.localhost",
  secret: ENV.fetch("COMPONENT_SECRET", "secret"),
  host: ENV.fetch("XMPP_HOST", "localhost"),
  port: ENV.fetch("XMPP_COMPONENT_PORT", "5347").to_i,
  name: "PubSub Service with Delegation",
  category: "pubsub",
  type: "service",
  log_file: STDOUT
)

# Create router for handling stanzas
router = XMPP::Router.new

# Handle delegated PubSub requests
router.route(->(s : XMPP::Sender, p : XMPP::Stanza::Packet) {
  if iq = p.as?(XMPP::Stanza::IQ)
    puts "Received IQ: #{iq.type} from #{iq.from}"

    # Check if this is a PubSub request
    if payload = iq.payload
      if payload.namespace == "http://jabber.org/protocol/pubsub"
        puts "Handling delegated PubSub request"

        # Process the request and send response
        response = XMPP::Stanza::IQ.new
        response.type = "result"
        response.id = iq.id
        response.to = iq.from
        response.from = iq.to

        s.send(response)
      end
    end
  end
}).iq_namespaces(["http://jabber.org/protocol/pubsub"])

# Create component
component = XMPP::Component.new(options, router)

# Setup signal handlers for graceful shutdown
Signal::INT.trap do
  puts "\nShutting down component..."
  component.disconnect
  exit 0
end

Signal::TERM.trap do
  puts "\nShutting down component..."
  component.disconnect
  exit 0
end

puts "Starting component: #{options.domain}"
puts "Connecting to: #{options.host}:#{options.port}"
puts ""
puts "Features:"
puts "  - XEP-0030: Service Discovery"
puts "  - XEP-0114: Component Protocol"
puts "  - XEP-0355: Namespace Delegation (component-side)"
puts "  - XEP-0356: Privileged Entity (component-side)"
puts ""
puts "The component will:"
puts "  1. Connect and authenticate"
puts "  2. Receive delegation/privilege advertisements from server"
puts "  3. Handle delegated namespaces (e.g., PubSub)"
puts "  4. Use privileges (roster access, message sending)"
puts ""
puts "Press Ctrl+C to stop"
puts ""

begin
  # Connect to server
  component.connect

  puts "✓ Component connected and authenticated"
  puts ""

  # Check what delegations we received
  unless component.delegation_manager.delegations.empty?
    puts "Delegated namespaces:"
    component.delegation_manager.delegations.each do |nsm, info|
      puts "  - #{nsm}"
      unless info.attributes.empty?
        puts "    Filtering attributes: #{info.attributes.join(", ")}"
      end
    end
    puts ""
  end

  # Check what privileges we received
  unless component.privilege_manager.permissions.empty?
    puts "Granted privileges:"
    component.privilege_manager.permissions.each do |access, perm|
      puts "  - #{access}: #{perm.type}"
      if access == "roster" && perm.push
        puts "    (with roster pushes)"
      end
    end
    puts ""
  end

  # Example: Manually grant privileges (for testing without server support)
  # In production, these would come from server advertisements
  puts "Note: If server doesn't advertise privileges, you can manually grant them:"
  puts "  component.grant_privilege(\"roster\", \"both\", push: true)"
  puts "  component.grant_privilege(\"message\", \"outgoing\")"
  puts ""

  # Keep component running
  puts "Component is running and ready to handle requests..."
  sleep
rescue ex : XMPP::ComponentError
  puts "Component error: #{ex.message}"
  exit 1
rescue ex : Exception
  puts "Error: #{ex.message}"
  puts ex.backtrace.join("\n")
  exit 1
end
