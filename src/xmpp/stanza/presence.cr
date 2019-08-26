require "./error"

module XMPP::Stanza
  # RFC 6120: part of A.5 Client Namespace and A.6 Server Namespace

  PRESENCE_SHOW_AWAY = "away"
  PRESENCE_SHOW_CHAT = "chat"
  PRESENCE_SHOW_DND  = "dnd"
  PRESENCE_SHOW_XA   = "xa"

  # Presence Packet
  # Presence implements RFC 6120 - A.5 Client Namespace (a part)
  # Presence stanzas are used to express an entity's current network
  # availability (offline or online, along with various sub-states of the
  # latter and optional user-defined descriptive text), and to notify other
  # entities of that availability. Presence stanzas are also used to negotiate
  # and manage subscriptions to the presence of other entities.
  class Presence < Extension
    class_getter xml_name : String = "presence"
    include Packet
    include Attrs
    property show : String = ""
    property status : String = ""
    property priority : Int8 = 0_i8
    property error : Error? = nil
    property extensions : Array(PresExtension) = Array(PresExtension).new

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
      raise "Invalid node(#{node.name}) expecting: #{@@xml_name}" unless node.name == @@xml_name
      cls = new()
      cls.load_attrs(node)
      node.children.select(&.element?).each do |child|
        case child.name
        when "show"     then cls.show = child.content
        when "status"   then cls.status = child.content
        when "priority" then cls.priority = child.content.to_i8
        when "error"    then cls.error = Error.new(child)
        else
          begin
            ext = Registry.get_pres_extension XMLName.new(child.namespace.try &.href || "", child.name), child
            unless ext.nil?
              cls.extensions << ext.as(PresExtension)
            end
          rescue ex
            XMPP::Logger.warn ex
          end
        end
      end
      cls
    end

    def to_xml(elem : XML::Builder)
      dict = attr_hash
      elem.element(@@xml_name, dict) do
        elem.element("show") { elem.text show } unless show.blank?
        elem.element("status") { elem.text status } unless status.blank?
        elem.element("priority") { elem.text priority.to_s } unless priority == 0
        error.try &.to_xml elem
        extensions.each do |v|
          v.to_xml elem
        end
      end
    end

    def name : String
      @@xml_name
    end

    # get search and extracts a specific extension on a presence stanza.
    # it will return extension instance if found on stanza else return nil
    def get(type : PresExtension.class)
      extensions.find &.class.<=(type)
    end
  end
end

require "./presence/*"
