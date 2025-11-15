require "./packet"
require "xml"

module XMPP::Stanza
  abstract class Extension
    include Packet
  end

  abstract class MsgExtension < Extension; end

  abstract class PresExtension < Extension; end

  # abstract class IQPayload < Extension
  module IQPayload
    abstract def namespace : String
  end

  # We store different registries per packet type and namespace
  private record RegistryKey, packet_type : PacketType, namespace : String

  private class Registry
    alias RegistryForNamespace = Hash(String, Extension.class)
    # We store different registries per packet type and namespace
    @@msg_types = Hash(RegistryKey, RegistryForNamespace).new
    # Handle concurrent access
    @@msg_type_lock = Mutex.new

    # map_extension stores extension type for packet payload.
    # The match is done per PacketType (iq, message, or presence) and XML tag name.
    # You can use the alias "*" as local XML name to be able to match all unknown tag name for that
    # packet type and namespace.

    def self.map_extension(pkt_type : PacketType, name : XMLName, extension : Extension.class)
      key = RegistryKey.new pkt_type, name.space
      @@msg_type_lock.synchronize {
        store = @@msg_types[key]? || RegistryForNamespace.new
        store[name.local] = extension
        @@msg_types[key] = store
      }
    end

    # get_extension_type returns the extension type for packet payload, based on the packet type and tag name
    def self.get_extension_type(pkt_type : PacketType, name : XMLName)
      key = RegistryKey.new pkt_type, name.space
      @@msg_type_lock.synchronize {
        raise "No #{pkt_type} Extension Handler for packet namespace \"#{name.space}\" Found" unless @@msg_types.has_key?(key)
        store = @@msg_types[key]
        result = store[name.local]?
        return store["*"] if result.nil? && name.local != "*"
        result.not_nil!
      }
    end

    # get_pres_extension returns an instance of PresExtension, by matching packet type and
    # XML tag name against the registry
    def self.get_pres_extension(name : XMLName, node : XML::Node)
      ext = get_extension_type PacketType::Presence, name
      return ext.new(node) if ext < PresExtension
      raise "Unable to find PresExtension for XML Tag: #{name.local}"
    end

    # get_msg_extension returns an instance of MsgExtension, by matching packet type and
    # XML tag name against the registry
    def self.get_msg_extension(name : XMLName, node : XML::Node)
      ext = get_extension_type PacketType::Message, name
      return ext.new(node) if ext < MsgExtension
      raise "Unable to find MsgExtension for XML Tag: #{name.local}"
    end

    # get_iq_extension returns an instance of IQ, by matching packet type and
    # XML tag name against the registry
    def self.get_iq_extension(name : XMLName, node : XML::Node)
      ext = get_extension_type PacketType::IQ, name
      return ext.new(node) if ext < IQPayload
      raise "Unable to find IQPayload for XML Tag: #{name.local}"
    end
  end
end
