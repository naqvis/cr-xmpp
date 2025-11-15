require "../stanza"
require "./registry"

module XMPP::Stanza
  # XEP-0480: SASL Upgrade Tasks
  # SASL2 User Agent - XEP-0388
  class SASL2UserAgent
    property id : String = ""
    property software : String = ""
    property device : String = ""

    def initialize(@id = "", @software = "", @device = "")
    end

    def self.new(node : XML::Node)
      cls = new()
      if id_attr = node.attributes["id"]?
        cls.id = id_attr.content
      end
      node.children.select(&.element?).each do |child|
        case child.name
        when "software" then cls.software = child.content
        when "device"   then cls.device = child.content
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      attrs = Hash(String, String).new
      attrs["id"] = id unless id.blank?
      xml.element("user-agent", attrs) do
        xml.element("software") { xml.text software } unless software.blank?
        xml.element("device") { xml.text device } unless device.blank?
      end
    end
  end

  # SASL2 Authenticate - XEP-0388 with XEP-0480 upgrade support
  class SASL2Authenticate
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_SASL2, "authenticate")
    property mechanism : String = ""
    property initial_response : String = ""
    property user_agent : SASL2UserAgent? = nil
    property upgrades : Array(String) = Array(String).new

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        case attr.name
        when "mechanism" then cls.mechanism = attr.content
        end
      end
      node.children.select(&.element?).each do |child|
        ns = child.namespace.try &.href
        case {child.name, ns}
        when {"initial-response", NS_SASL2}
          cls.initial_response = child.content
        when {"user-agent", NS_SASL2}
          cls.user_agent = SASL2UserAgent.new(child)
        when {"upgrade", NS_SASL_UPGRADE}
          cls.upgrades << child.content
        end
      end
      cls
    end

    def initialize(@mechanism = "", @initial_response = "", @user_agent = nil, @upgrades = Array(String).new)
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["mechanism"] = mechanism unless mechanism.blank?

      xml.element(@@xml_name.local, dict) do
        xml.element("initial-response") { xml.text initial_response } unless initial_response.blank?
        user_agent.try &.to_xml(xml)
        upgrades.each do |upgrade|
          xml.element("upgrade", {"xmlns" => NS_SASL_UPGRADE}) { xml.text upgrade }
        end
      end
    end

    def name : String
      "sasl2:authenticate"
    end
  end

  # SASL2 Continue - Server requests upgrade task
  class SASL2Continue
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_SASL2, "continue")
    property additional_data : String = ""
    property tasks : Array(String) = Array(String).new
    property text : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "additional-data"
          cls.additional_data = child.content
        when "tasks"
          child.children.select(&.element?).each do |task_child|
            cls.tasks << task_child.content if task_child.name == "task"
          end
        when "text"
          cls.text = child.content
        end
      end
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.element("additional-data") { xml.text additional_data } unless additional_data.blank?
        unless tasks.empty?
          xml.element("tasks") do
            tasks.each { |task| xml.element("task") { xml.text task } }
          end
        end
        xml.element("text") { xml.text text } unless text.blank?
      end
    end

    def name : String
      "sasl2:continue"
    end
  end

  # SASL2 Next - Client initiates upgrade task
  class SASL2Next
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_SASL2, "next")
    property task : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.attributes.each do |attr|
        cls.task = attr.content if attr.name == "task"
      end
      cls
    end

    def initialize(@task = "")
    end

    def to_xml(xml : XML::Builder)
      dict = Hash(String, String).new
      dict["xmlns"] = @@xml_name.space
      dict["task"] = task unless task.blank?
      xml.element(@@xml_name.local, dict)
    end

    def name : String
      "sasl2:next"
    end
  end

  # SASL2 TaskData - Bidirectional task data exchange
  class SASL2TaskData
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_SASL2, "task-data")
    property salt : String = ""
    property iterations : Int32 = 0
    property hash : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        ns = child.namespace.try &.href
        case {child.name, ns}
        when {"salt", NS_SCRAM_UPGRADE}
          cls.salt = child.content
          if iter_attr = child.attributes["iterations"]?
            cls.iterations = iter_attr.content.to_i32
          end
        when {"hash", NS_SCRAM_UPGRADE}
          cls.hash = child.content
        end
      end
      cls
    end

    def initialize(@salt = "", @iterations = 0, @hash = "")
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        if !salt.blank? && iterations > 0
          xml.element("salt", {"xmlns" => NS_SCRAM_UPGRADE, "iterations" => iterations.to_s}) do
            xml.text salt
          end
        end
        if !hash.blank?
          xml.element("hash", {"xmlns" => NS_SCRAM_UPGRADE}) { xml.text hash }
        end
      end
    end

    def name : String
      "sasl2:task-data"
    end
  end

  # SASL2 Challenge
  class SASL2Challenge
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_SASL2, "challenge")
    property body : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      cls.body = node.text
      cls
    end

    def initialize(@body = "")
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.text body unless body.blank?
      end
    end

    def name : String
      "sasl2:challenge"
    end
  end

  # SASL2 Response
  class SASL2Response
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_SASL2, "response")
    property body : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      cls.body = node.text
      cls
    end

    def initialize(@body = "")
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        xml.text body unless body.blank?
      end
    end

    def name : String
      "sasl2:response"
    end
  end

  # SASL2 Success - Enhanced with authorization identifier
  class SASL2Success
    include Packet
    class_getter xml_name : XMLName = XMLName.new(NS_SASL2, "success")
    property authorization_identifier : String = ""
    property body : String = ""

    def self.new(node : XML::Node)
      raise "Invalid node(#{node.name}), expecting #{@@xml_name}" unless (node.namespace.try &.href == @@xml_name.space) && (node.name == @@xml_name.local)
      cls = new()
      node.children.select(&.element?).each do |child|
        case child.name
        when "authorization-identifier"
          cls.authorization_identifier = child.content
        end
      end
      cls.body = node.text if cls.authorization_identifier.blank?
      cls
    end

    def to_xml(xml : XML::Builder)
      xml.element(@@xml_name.local, xmlns: @@xml_name.space) do
        if !authorization_identifier.blank?
          xml.element("authorization-identifier") { xml.text authorization_identifier }
        elsif !body.blank?
          xml.text body
        end
      end
    end

    def name : String
      "sasl2:success"
    end
  end
end
