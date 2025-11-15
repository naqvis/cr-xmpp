require "./event_manager"
require "./stanza"

module XMPP
  # Stream Management (XEP-0198) support module
  # Handles outbound stanza tracking and automatic resend on resume
  module StreamManagement
    # Maximum number of unacknowledged stanzas to queue
    MAX_QUEUE_SIZE = 100

    # Track if stream management is enabled
    @sm_enabled : Bool = false

    # Send a stanza with stream management tracking
    def send_with_sm(stanza : Stanza::Packet)
      send_with_sm(stanza.to_xml)
    end

    # Send a stanza string with stream management tracking
    def send_with_sm(xml : String)
      # Only queue if SM is enabled and this is a stanza (not nonza)
      if @sm_enabled && should_track_stanza?(xml)
        @session.sm_state.queue_stanza(xml)

        # Check queue size and request ack if needed
        if @session.sm_state.unacked_stanzas.size >= MAX_QUEUE_SIZE / 2
          request_ack
        end
      end

      # Send the stanza
      @session.send(xml)
    end

    # Request acknowledgement from server
    private def request_ack
      request = Stanza::SMRequest.new
      @session.send(request.to_xml)
    end

    # Process acknowledgement from server
    def process_sm_ack(h : UInt32)
      @session.sm_state.process_ack(h)
    end

    # Enable stream management tracking
    def enable_sm_tracking
      @sm_enabled = true
      Logger.debug "Stream Management tracking enabled"
    end

    # Disable stream management tracking
    def disable_sm_tracking
      @sm_enabled = false
      Logger.debug "Stream Management tracking disabled"
    end

    # Check if stream management is enabled
    def sm_enabled? : Bool
      @sm_enabled
    end

    # Resend unacknowledged stanzas after resume
    def resend_unacked_stanzas
      stanzas = @session.sm_state.stanzas_to_resend
      return if stanzas.empty?

      Logger.info "Resending #{stanzas.size} unacknowledged stanzas"

      stanzas.each do |stanza|
        begin
          @session.send(stanza)
        rescue ex
          Logger.error "Failed to resend stanza: #{ex.message}"
        end
      end

      # Clear the queue after resending
      @session.sm_state.clear_queue
    end

    # Check if a stanza should be tracked
    # Only track <message>, <iq>, and <presence> stanzas
    private def should_track_stanza?(xml : String) : Bool
      # Simple check - stanzas start with <message, <iq, or <presence
      xml.starts_with?("<message") || xml.starts_with?("<iq") || xml.starts_with?("<presence")
    end
  end
end
