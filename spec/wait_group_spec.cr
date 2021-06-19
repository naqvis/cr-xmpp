require "./spec_helper"

module XMPP
  describe WaitGroup do

    it "Should not block on creation" do
      wg = WaitGroup.new
      wg.wait
    end

    it "Should block whilst not done" do
      wg = WaitGroup.new
      wg.add.should eq 1
      progress = Atomic(Int32).new(0)
      spawn { progress.add(1); wg.wait; progress.add(1) }
      sleep 5.milliseconds
      # Should get to wait but not beyond it
      progress.get.should eq 1
      wg.done.should eq 0
      while progress.get != 2
         sleep 1.milliseconds
      end
    end

    it "Should support multiple waiters" do
      wg = WaitGroup.new
      wg.add.should eq 1
      unblocked = Atomic(Int32).new(0)
      nwaiters = 10
      (1..nwaiters).each { spawn { wg.wait; unblocked.add(1) } }
      sleep 5.milliseconds
      unblocked.get.should eq 0
      wg.done.should eq 0
      while unblocked.get != nwaiters
        sleep 1.milliseconds
      end
    end

    it "Won't block again after done" do
      wg = WaitGroup.new
      wg.add
      wg.done
      wg.done?.should be_true
      wg.wait
      wg.add
      wg.done?.should be_true
    end

  end
end
