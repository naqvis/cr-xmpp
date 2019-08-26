require "xml"
require "./error"
require "./packet"
require "./registry"

module XMPP::Stanza
  # Message Packet
  # Message implements RFC 6120 - A.5 Client Namespace (a part)
  # [RFC 3921 Section 2.1 - Message Syntax](http://xmpp.org/rfcs/rfc3921.html#rfc.section.2.1)
  #
  # Exchanging messages is a basic use of XMPP and occurs when a user
  # generates a message stanza that is addressed to another entity. The
  # sender's server is responsible for delivering the message to the intended
  # recipient (if the recipient is on the same local server) or for routing
  # the message to the recipient's server (if the recipient is on a remote
  # server). Thus a message stanza is used to "push" information to another
  # entity.
  # ## "Subject" Element
  #
  # The `subject` element contains human-readable XML character data that
  # specifies the topic of the message.
  # ## "Body" Element
  #
  # The `body` element contains human-readable XML character data that
  # specifies the textual contents of the message; this child element is
  # normally included but is optional.
  # ## "Thread" Element
  #
  # The primary use of the XMPP `thread` element is to uniquely identify a
  # conversation thread or "chat session" between two entities instantiated by
  # Message stanzas of type `chat`. However, the XMPP thread element can also
  # be used to uniquely identify an analogous thread between two entities
  # instantiated by Message stanzas of type `headline` or `normal`, or among
  # multiple entities in the context of a multi-user chat room instantiated by
  # Message stanzas of type `groupchat`. It MAY also be used for Message
  # stanzas not related to a human conversation, such as a game session or an
  # interaction between plugins. The `thread` element is not used to identify
  # individual messages, only conversations or messagingg sessions. The
  # inclusion of the `thread` element is optional.
  #
  # The value of the `thread` element is not human-readable and MUST be
  # treated as opaque by entities; no semantic meaning can be derived from it,
  # and only exact comparisons can be made against it. The value of the
  # `thread` element MUST be a universally unique identifier (UUID) as
  # described in [UUID].
  #
  # The `thread` element MAY possess a 'parent' attribute that identifies
  # another thread of which the current thread is an offshoot or child; the
  # value of the 'parent' must conform to the syntax of the `thread` element
  # itself.
  #
  class Message < Extension
    class_getter xml_name : String = "message"
    include Packet
    include Attrs
    property subject : String = ""
    property body : String = ""
    property thread : String = ""
    property error : Error? = nil
    property extensions : Array(Extension) = Array(Extension).new

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
      raise "Invalid #{@@xml_name} node: #{node.name}" unless node.name == @@xml_name
      pr = new()
      pr.load_attrs(node)
      node.children.select(&.element?).each do |child|
        case child.name
        when "subject" then pr.subject = child.content
        when "body"    then pr.body = child.content
        when "thread"  then pr.thread = child.content
        when "error"   then pr.error = Error.new(child)
        else
          begin
            ext = Registry.get_msg_extension XMLName.new(child.namespace.try &.href || "", child.name), child
            unless ext.nil?
              pr.extensions << ext
            end
          rescue ex
            XMPP::Logger.warn ex
          end
        end
      end
      pr
    end

    # get search and extracts a specific extension on a message.
    # it will return extension instance if found on message else return nil
    def get(type : MsgExtension.class)
      extensions.find &.class.<=(type)
    end

    def xmpp_format
      msg = XML.build(indent: "", quote_char: '"') do |xml|
        to_xml xml
      end
      msg
    end

    def to_xml(elem : XML::Builder)
      dict = attr_hash

      elem.element(@@xml_name, dict) do
        elem.element("subject") { elem.text subject } unless subject.blank?
        elem.element("body") { elem.text body } unless body.blank?
        elem.element("thread") { elem.text thread } unless thread.blank?
        error.try &.to_xml elem
        extensions.each { |e| e.to_xml elem }
      end
    end

    def name : String
      "message"
    end
  end
end

require "./message/*"
