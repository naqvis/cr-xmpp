require "../stanza"

module XMPP::Stanza
  # Generic / unknown content

  class Nodes
    getter nodes : Array(Node) = Array(Node).new

    def self.new(node : XML::NodeSet)
      pr = new()
      node.select(&.element?).each do |child|
        pr.nodes << Node.new child
      end
      pr
    end

    def to_xml
      val = XML.build(quote_char: '\'') do |xml|
        to_xml xml
      end
      val.sub(%(<?xml version='1.0'?>), "").lstrip("\n")
    end

    def to_xml(elem : XML::Builder)
      elem.element("xml") do
        @nodes.each { |n| n.to_xml elem }
      end
    end
  end

  # Node is a generic structure to represent XML data. It is used to parse
  # unreferenced or custom stanza payload.

  class Node
    property xml_name : XMLName
    getter attrs : Hash(String, String)
    property contents : String = ""
    getter nodes : Array(Node)

    def initialize
      @xml_name = XMLName.new("", "")
      @attrs = Hash(String, String).new
      @nodes = Array(Node).new
    end

    def self.new(node : XML::Node)
      pr = new()
      ns = node.namespace.try &.href || ""
      pr.xml_name = XMLName.new(space: ns, local: node.name)
      node.attributes.each do |attr|
        pr.attrs[attr.name] = attr.children[0].content
      end
      node.children.select(&.text?).each do |child|
        pr.contents = child.text
      end
      node.children.select(&.element?).each do |child|
        pr.nodes << Node.new(child)
      end
      pr
    end

    def to_xml
      XML.build(indent: "  ", quote_char: '\'') do |xml|
        to_xml xml
      end
    end

    def to_xml(elem : XML::Builder)
      attrs["xmlns"] = xml_name.space unless xml_name.space.blank?
      elem.element(xml_name.local, attrs) do
        elem.text contents unless contents.blank?
        nodes.each { |n| n.to_xml elem }
      end
    end

    def name : String
      xml_name.local
    end

    def namespace : String
      xml_name.space
    end
  end
end
