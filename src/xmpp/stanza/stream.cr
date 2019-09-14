require "./registry"

module XMPP::Stanza
  # StreamFeatures Packet
  # Reference: The active stream features are published on
  #            https://xmpp.org/registrar/stream-features.html
  # Note: That page misses draft and experimental XEP (i.e CSI, etc)
  class StreamFeatures < Extension
    include Packet
    # Server capabilities hash
    class_getter xml_name : XMLName = XMLName.new("http://etherx.jabber.org/streams features")
    property caps : Caps? = nil
    # Stream features
    property start_tls : TLSStartTLS? = nil
    property mechanisms : SASLMechanisms? = nil
    property bind : Bind? = nil
    property stream_management : StreamManagement? = nil
    # Obsolete
    property session : StreamSession? = nil
    # ProcessOne Stream Features
    property p1_push : P1Push? = nil
    property p1_rebind : P1Rebind? = nil
    property p1_ack : P1Ack? = nil
    property any : Array(Node) = Array(Node).new

    def self.new(xml : String)
      doc = XML.parse(xml)
      root = doc.first_element_child
      if (root)
        new(root)
      else
        raise "Invalid XML"
      end
    end

    def self.new(node : XML::Node)
      cls = new()
      node.children.select(&.element?).each do |child|
        ns = (child.namespace.try &.href) || ""
        case {child.name, ns}
        when {Caps.xml_name.local, Caps.xml_name.space}                         then cls.caps = Caps.new(child)
        when {TLSStartTLS.xml_name.local, TLSStartTLS.xml_name.space}           then cls.start_tls = TLSStartTLS.new(child)
        when {SASLMechanisms.xml_name.local, SASLMechanisms.xml_name.space}     then cls.mechanisms = SASLMechanisms.new(child)
        when {Bind.xml_name.local, Bind.xml_name.space}                         then cls.bind = Bind.new(child)
        when {StreamManagement.xml_name.local, StreamManagement.xml_name.space} then cls.stream_management = StreamManagement.new(child)
        when {StreamSession.xml_name.local, StreamSession.xml_name.space}       then cls.session = StreamSession.new(child)
        when {P1Push.xml_name.local, P1Push.xml_name.space}                     then cls.p1_push = P1Push.new(child)
        when {P1Rebind.xml_name.local, P1Rebind.xml_name.space}                 then cls.p1_rebind = P1Rebind.new(child)
        when {P1Ack.xml_name.local, P1Ack.xml_name.space}                       then cls.p1_ack = P1Ack.new(child)
        else
          cls.any << Node.new(child)
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      elem.element(@@xml_name.local, xmlns: @@xml_name.space) do
        caps.try &.to_xml elem
        start_tls.try &.to_xml elem
        mechanisms.try &.to_xml elem
        bind.try &.to_xml elem
        stream_management.try &.to_xml elem
        session.try &.to_xml elem
        p1_push.try &.to_xml elem
        p1_rebind.try &.to_xml elem
        p1_ack.try &.to_xml elem
        any.each do |v|
          v.to_xml elem
        end
      end
    end

    def name : String
      "stream:features"
    end

    def does_start_tls
      if (t = start_tls)
        return {t, true}
      end
      {TLSStartTLS.new, false}
    end

    def tls_required
      if (t = start_tls)
        return t.required
      end
      false
    end

    def does_stream_management
      !stream_management.nil?
    end
  end
end

require "./stream/**"
