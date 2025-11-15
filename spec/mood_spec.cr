require "./spec_helper"

describe "XEP-0107: User Mood" do
  describe XMPP::Stanza::Mood do
    it "parses mood with valid mood type" do
      xml = <<-XML
        <mood xmlns='http://jabber.org/protocol/mood'>
          <happy/>
          <text>Feeling great today!</text>
        </mood>
      XML

      mood = XMPP::Stanza::Mood.new(XML.parse(xml).first_element_child.not_nil!)

      mood.value.should eq "happy"
      mood.text.should eq "Feeling great today!"
      mood.valid_mood?.should be_true
    end

    it "parses mood without text" do
      xml = <<-XML
        <mood xmlns='http://jabber.org/protocol/mood'>
          <sad/>
        </mood>
      XML

      mood = XMPP::Stanza::Mood.new(XML.parse(xml).first_element_child.not_nil!)

      mood.value.should eq "sad"
      mood.text.should eq ""
      mood.valid_mood?.should be_true
    end

    it "parses mood with underscore in name" do
      xml = <<-XML
        <mood xmlns='http://jabber.org/protocol/mood'>
          <in_love/>
          <text>Found my soulmate</text>
        </mood>
      XML

      mood = XMPP::Stanza::Mood.new(XML.parse(xml).first_element_child.not_nil!)

      mood.value.should eq "in_love"
      mood.text.should eq "Found my soulmate"
      mood.valid_mood?.should be_true
    end

    it "accepts unknown mood types but marks as invalid" do
      xml = <<-XML
        <mood xmlns='http://jabber.org/protocol/mood'>
          <custom_mood/>
          <text>Custom mood</text>
        </mood>
      XML

      mood = XMPP::Stanza::Mood.new(XML.parse(xml).first_element_child.not_nil!)

      mood.value.should eq "custom_mood"
      mood.text.should eq "Custom mood"
      mood.valid_mood?.should be_false
    end

    it "parses empty mood (clearing mood)" do
      xml = <<-XML
        <mood xmlns='http://jabber.org/protocol/mood'/>
      XML

      mood = XMPP::Stanza::Mood.new(XML.parse(xml).first_element_child.not_nil!)

      mood.value.should eq ""
      mood.text.should eq ""
      mood.valid_mood?.should be_false
    end

    describe "#valid_mood?" do
      it "returns true for standard XEP-0107 moods" do
        standard_moods = ["happy", "sad", "angry", "excited", "tired", "in_love"]

        standard_moods.each do |mood_type|
          mood = XMPP::Stanza::Mood.new
          mood.value = mood_type
          mood.valid_mood?.should be_true
        end
      end

      it "returns false for non-standard moods" do
        mood = XMPP::Stanza::Mood.new
        mood.value = "custom_mood"
        mood.valid_mood?.should be_false
      end

      it "returns false for empty mood" do
        mood = XMPP::Stanza::Mood.new
        mood.valid_mood?.should be_false
      end
    end

    describe "#mood_description" do
      it "returns capitalized mood for simple moods" do
        mood = XMPP::Stanza::Mood.new
        mood.value = "happy"
        mood.mood_description.should eq "Happy"
      end

      it "converts underscores to spaces" do
        mood = XMPP::Stanza::Mood.new
        mood.value = "in_love"
        mood.mood_description.should eq "In love"
      end

      it "returns 'No mood set' for empty mood" do
        mood = XMPP::Stanza::Mood.new
        mood.mood_description.should eq "No mood set"
      end
    end

    it "serializes to XML correctly" do
      mood = XMPP::Stanza::Mood.new
      mood.value = "excited"
      mood.text = "Great news!"

      xml = mood.to_xml

      xml.should contain("<mood")
      xml.should contain("xmlns=\"http://jabber.org/protocol/mood\"")
      xml.should contain("<excited")
      xml.should contain("<text>Great news!</text>")
    end

    it "serializes empty mood correctly" do
      mood = XMPP::Stanza::Mood.new

      xml = mood.to_xml

      xml.should contain("<mood")
      xml.should contain("xmlns=\"http://jabber.org/protocol/mood\"")
      xml.should_not contain("<text>")
    end

    it "validates all XEP-0107 mood types" do
      # Test a sample of mood types to ensure they're all in the set
      sample_moods = [
        "afraid", "amazed", "angry", "anxious", "bored", "calm", "confused",
        "happy", "sad", "excited", "tired", "worried", "grateful", "lonely",
      ]

      sample_moods.each do |mood_type|
        XMPP::Stanza::Mood::VALID_MOODS.includes?(mood_type).should be_true
      end
    end
  end
end
