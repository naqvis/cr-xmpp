require "../../spec_helper"

module XMPP::Stanza
  describe ExplicitMessageEncryption do
    it "parses an EME marker (XEP-0380)" do
      xml = <<-XML
          <message from='alex@switzerland.ch' to='ali@wherever-you-are.org' type='chat'>
            <body>This message is encrypted.</body>
            <encryption xmlns='urn:xmpp:eme:0'
                        namespace='eu.siacs.conversations.axolotl'
                        name='OMEMO'/>
          </message>
          XML

      msg = Message.new xml
      fail "no extension parsed" if msg.extensions.empty?

      eme = msg.extensions.find { |e| e.is_a?(ExplicitMessageEncryption) }
      fail "no EME extension found" unless eme.is_a?(ExplicitMessageEncryption)
      eme.namespace.should eq("eu.siacs.conversations.axolotl")
      eme.name_attr.should eq("OMEMO")
    end

    it "serialises with namespace and name attrs" do
      ext = ExplicitMessageEncryption.new
      ext.namespace = ExplicitMessageEncryption::OMEMO_LEGACY_NS
      ext.name_attr = "OMEMO"

      out = XML.build { |xml| ext.to_xml(xml) }
      out.should contain(%(xmlns="urn:xmpp:eme:0"))
      out.should contain(%(namespace="eu.siacs.conversations.axolotl"))
      out.should contain(%(name="OMEMO"))
    end

    it "omits optional name attr when blank" do
      ext = ExplicitMessageEncryption.new
      ext.namespace = ExplicitMessageEncryption::OMEMO_V2_NS

      out = XML.build { |xml| ext.to_xml(xml) }
      out.should_not contain("name=")
    end
  end
end
