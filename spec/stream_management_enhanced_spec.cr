require "./spec_helper"

describe "Stream Management - Enhanced Features" do
  describe XMPP::SMState do
    describe "outbound tracking" do
      it "initializes with outbound counter" do
        state = XMPP::SMState.new
        state.outbound.should eq 0_u32
      end

      it "queues stanzas" do
        state = XMPP::SMState.new

        state.queue_stanza("<message><body>test</body></message>")
        state.queue_stanza("<iq type='get'/>")

        state.outbound.should eq 2_u32
        state.unacked_stanzas.size.should eq 2
      end

      it "tracks unacknowledged stanzas" do
        state = XMPP::SMState.new

        state.queue_stanza("<message id='1'/>")
        state.queue_stanza("<message id='2'/>")
        state.queue_stanza("<message id='3'/>")

        state.has_unacked_stanzas?.should be_true
        state.unacked_stanzas.size.should eq 3
      end
    end

    describe "#process_ack" do
      it "removes acknowledged stanzas from queue" do
        state = XMPP::SMState.new

        # Queue 5 stanzas
        5.times do |i|
          state.queue_stanza("<message id='#{i}'/>")
        end

        state.unacked_stanzas.size.should eq 5

        # Server acknowledges first 3 stanzas (h=3)
        state.process_ack(3_u32)

        state.unacked_stanzas.size.should eq 2
      end

      it "handles acknowledgement of all stanzas" do
        state = XMPP::SMState.new

        3.times { |i| state.queue_stanza("<message id='#{i}'/>") }

        # Server acknowledges all 3 stanzas
        state.process_ack(3_u32)

        state.unacked_stanzas.should be_empty
        state.has_unacked_stanzas?.should be_false
      end

      it "handles partial acknowledgements correctly" do
        state = XMPP::SMState.new

        # Queue 10 stanzas
        10.times { |i| state.queue_stanza("<message id='#{i}'/>") }

        # Server acks first 5
        state.process_ack(5_u32)
        state.unacked_stanzas.size.should eq 5

        # Server acks 3 more (total 8)
        state.process_ack(8_u32)
        state.unacked_stanzas.size.should eq 2

        # Server acks remaining
        state.process_ack(10_u32)
        state.unacked_stanzas.should be_empty
      end
    end

    describe "#stanzas_to_resend" do
      it "returns copy of unacknowledged stanzas" do
        state = XMPP::SMState.new

        stanza1 = "<message id='1'/>"
        stanza2 = "<message id='2'/>"

        state.queue_stanza(stanza1)
        state.queue_stanza(stanza2)

        to_resend = state.stanzas_to_resend
        to_resend.size.should eq 2
        to_resend[0].should eq stanza1
        to_resend[1].should eq stanza2
      end

      it "returns empty array when no unacked stanzas" do
        state = XMPP::SMState.new
        state.stanzas_to_resend.should be_empty
      end
    end

    describe "#clear_queue" do
      it "clears all unacknowledged stanzas" do
        state = XMPP::SMState.new

        5.times { |i| state.queue_stanza("<message id='#{i}'/>") }
        state.unacked_stanzas.size.should eq 5

        state.clear_queue

        state.unacked_stanzas.should be_empty
        state.has_unacked_stanzas?.should be_false
      end
    end

    describe "integration scenario" do
      it "handles complete send-ack-resend cycle" do
        state = XMPP::SMState.new(id: "session123")

        # Send 10 messages
        10.times { |i| state.queue_stanza("<message id='msg#{i}'/>") }
        state.outbound.should eq 10_u32
        state.unacked_stanzas.size.should eq 10

        # Server acks first 7
        state.process_ack(7_u32)
        state.unacked_stanzas.size.should eq 3

        # Connection drops, need to resend remaining 3
        to_resend = state.stanzas_to_resend
        to_resend.size.should eq 3
        to_resend[0].should contain("msg7")
        to_resend[1].should contain("msg8")
        to_resend[2].should contain("msg9")

        # After successful resend, clear queue
        state.clear_queue
        state.has_unacked_stanzas?.should be_false
      end
    end
  end

  describe "Stream Management Answer parsing" do
    it "parses SMAnswer stanza" do
      xml = <<-XML
        <a xmlns='urn:xmpp:sm:3' h='5'/>
      XML

      answer = XMPP::Stanza::SMAnswer.new(XML.parse(xml).first_element_child.not_nil!)
      answer.h.should eq 5_u32
    end

    it "handles large h values" do
      xml = <<-XML
        <a xmlns='urn:xmpp:sm:3' h='1000'/>
      XML

      answer = XMPP::Stanza::SMAnswer.new(XML.parse(xml).first_element_child.not_nil!)
      answer.h.should eq 1000_u32
    end
  end
end
