require "../stanza"

module XMPP
  # XEP-0355: Namespace Delegation - Component Side Implementation
  # Allows components to handle delegated namespaces from the server
  module ComponentDelegation
    # Stores information about delegated namespaces
    class DelegationInfo
      property namespace : String
      property attributes : Array(String) = Array(String).new

      def initialize(@namespace, @attributes = [] of String)
      end

      # Check if a stanza matches this delegation (considering filtering attributes)
      def matches?(stanza : Stanza::Packet) : Bool
        return false unless stanza.is_a?(Stanza::IQ)

        iq = stanza.as(Stanza::IQ)
        payload = iq.payload
        return false unless payload

        # Check if payload namespace matches
        return false unless payload.namespace == @namespace

        # If there are filtering attributes, check them
        if @attributes.empty?
          return true
        end

        # For filtering attributes, we need to check the payload
        # This is a simplified check - real implementation would inspect XML
        true
      end
    end

    # Manages delegated namespaces for a component
    class DelegationManager
      property delegations : Hash(String, DelegationInfo) = Hash(String, DelegationInfo).new

      # Add a delegated namespace
      def add_delegation(namespace : String, attributes : Array(String) = [] of String)
        @delegations[namespace] = DelegationInfo.new(namespace, attributes)
        Logger.info "Delegation granted for namespace: #{namespace}"
      end

      # Check if a namespace is delegated
      def delegated?(namespace : String) : Bool
        @delegations.has_key?(namespace)
      end

      # Get delegation info for a namespace
      def get_delegation(namespace : String) : DelegationInfo?
        @delegations[namespace]?
      end

      # Check if a stanza should be handled by delegation
      def should_handle?(stanza : Stanza::Packet) : Bool
        return false unless stanza.is_a?(Stanza::IQ)

        iq = stanza.as(Stanza::IQ)
        payload = iq.payload
        return false unless payload

        delegation = @delegations[payload.namespace]?
        return false unless delegation

        delegation.matches?(stanza)
      end
    end

    # Instance variables for delegation
    @delegation_manager : DelegationManager = DelegationManager.new

    def delegation_manager : DelegationManager
      @delegation_manager
    end

    # Handle delegation advertisement from server
    # Called when server sends <message> with <delegation> element
    def handle_delegation_advertisement(delegation : Stanza::Delegation)
      delegation.delegated.each do |delegated|
        attributes = delegated.attributes.map(&.name)
        @delegation_manager.add_delegation(delegated.namespace, attributes)
      end
    end

    # Process a delegated stanza from server
    # Server sends: <iq type='set'><delegation><forwarded><iq>...</iq></forwarded></delegation></iq>
    def process_delegated_stanza(wrapper_iq : Stanza::IQ) : Stanza::IQ?
      return nil unless wrapper_iq.type == "set"

      delegation = wrapper_iq.payload.as?(Stanza::Delegation)
      return nil unless delegation

      forwarded = delegation.forwarded
      return nil unless forwarded

      # Extract the original stanza
      original_stanza = forwarded.stanza
      return nil unless original_stanza.is_a?(Stanza::IQ)

      original_iq = original_stanza.as(Stanza::IQ)

      # Verify this is a delegated namespace we handle
      if original_iq.payload && @delegation_manager.delegated?(original_iq.payload.namespace)
        Logger.debug "Processing delegated stanza for namespace: #{original_iq.payload.namespace}"
        return original_iq
      end

      nil
    end

    # Wrap a response to a delegated stanza
    # Component sends: <iq type='result'><delegation><forwarded><iq>...</iq></forwarded></delegation></iq>
    def wrap_delegated_response(original_wrapper_id : String, response_iq : Stanza::IQ, to : String) : Stanza::IQ
      # Create forwarded wrapper
      forwarded = Stanza::Forwarded.new
      forwarded.stanza = response_iq

      # Create delegation wrapper
      delegation = Stanza::Delegation.new
      delegation.forwarded = forwarded

      # Create wrapper IQ
      wrapper = Stanza::IQ.new
      wrapper.type = "result"
      wrapper.id = original_wrapper_id
      wrapper.to = to
      wrapper.payload = delegation

      wrapper
    end

    # Setup delegation handlers
    def setup_delegation_handlers
      # Handle delegation advertisements (in messages)
      @router.route(->(_s : Sender, p : Stanza::Packet) {
        if msg = p.as?(Stanza::Message)
          if delegation = msg.extensions.find { |ext| ext.is_a?(Stanza::Delegation) }
            handle_delegation_advertisement(delegation.as(Stanza::Delegation))
          end
        end
      }).message

      # Handle delegated stanzas (in IQs)
      @router.route(->(s : Sender, p : Stanza::Packet) {
        if iq = p.as?(Stanza::IQ)
          if original_iq = process_delegated_stanza(iq)
            # Route the unwrapped stanza to appropriate handler
            # The handler should process it and send back a response
            # which will be wrapped by wrap_delegated_response
            handle_delegated_iq(s, iq, original_iq)
          end
        end
      }).iq_namespaces(["urn:xmpp:delegation:1", "urn:xmpp:delegation:2"])
    end

    # Override this method to handle delegated IQs
    # Default implementation logs and returns service-unavailable
    def handle_delegated_iq(sender : Sender, wrapper_iq : Stanza::IQ, original_iq : Stanza::IQ)
      Logger.warn "Received delegated IQ but no handler implemented for namespace: #{original_iq.payload.try &.namespace}"

      # Send error response
      error_iq = Stanza::IQ.new
      error_iq.type = "error"
      error_iq.id = original_iq.id
      error_iq.to = original_iq.from
      error_iq.from = original_iq.to

      # Wrap and send
      response = wrap_delegated_response(wrapper_iq.id, error_iq, wrapper_iq.from)
      send(response)
    end
  end
end
