require "xml"

module XMPP::DOAP
  RDF_NS    = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  DOAP_NS   = "http://usefulinc.com/ns/doap#"
  XMPP_NS   = "https://linkmauve.fr/ns/xmpp-doap#"
  SCHEMA_NS = "https://schema.org/"
  XML_NS    = "http://www.w3.org/XML/1998/namespace"

  class ParseError < Exception; end

  enum SupportStatus
    Complete
    Partial
    Planned
    Deprecated
    Removed
    Wontfix

    def self.from_xml(value : String) : self
      case value
      when "complete"   then Complete
      when "partial"    then Partial
      when "planned"    then Planned
      when "deprecated" then Deprecated
      when "removed"    then Removed
      when "wontfix"    then Wontfix
      else
        raise ParseError.new("Invalid XEP support status: #{value}")
      end
    end

    def to_s : String
      case self
      in Complete   then "complete"
      in Partial    then "partial"
      in Planned    then "planned"
      in Deprecated then "deprecated"
      in Removed    then "removed"
      in Wontfix    then "wontfix"
      end
    end
  end

  record LocalizedText, value : String, language : String? = nil

  class SupportedXep
    getter xep : String
    property status : SupportStatus
    property version : String?
    property since : String?
    getter notes : Array(LocalizedText)

    def initialize(
      @xep : String,
      @status : SupportStatus,
      @version : String? = nil,
      @since : String? = nil,
      @notes : Array(LocalizedText) = [] of LocalizedText,
    )
      raise ArgumentError.new("xep cannot be empty") if @xep.blank?
    end

    def self.from_xml(node : XML::Node) : self
      unless DOAP.namespace(node) == XMPP_NS && node.name == "SupportedXep"
        raise ParseError.new("Expected xmpp:SupportedXep")
      end

      xep = nil.as(String?)
      status = nil.as(SupportStatus?)
      version = nil.as(String?)
      since = nil.as(String?)
      notes = [] of LocalizedText

      node.children.select(&.element?).each do |child|
        next unless DOAP.namespace(child) == XMPP_NS

        case child.name
        when "xep"     then xep = DOAP.resource(child)
        when "status"  then status = SupportStatus.from_xml(child.content.strip)
        when "version" then version = child.content
        when "since"   then since = child.content
        when "note"    then notes << LocalizedText.new(child.content, DOAP.language(child))
        end
      end

      raise ParseError.new("SupportedXep is missing xmpp:xep") unless xep
      raise ParseError.new("SupportedXep is missing xmpp:status") unless status

      new(xep, status, version, since, notes)
    end

    def to_xml(xml : XML::Builder) : Nil
      xml.element("implements") do
        xml.element("xmpp:SupportedXep") do
          xml.element("xmpp:xep", {"rdf:resource" => xep})
          xml.element("xmpp:status") { xml.text status.to_s }
          xml.element("xmpp:version") { xml.text version.not_nil! } if version
          xml.element("xmpp:since") { xml.text since.not_nil! } if since
          notes.each do |note|
            attributes = {} of String => String
            attributes["xml:lang"] = note.language.not_nil! if note.language
            xml.element("xmpp:note", attributes) { xml.text note.value }
          end
        end
      end
    end
  end

  class Repository
    property kind : String
    property browse : String?
    property location : String?

    def initialize(
      @kind : String = "GitRepository",
      @browse : String? = nil,
      @location : String? = nil,
    )
    end

    def self.from_xml(node : XML::Node) : self
      repository = node.children.find(&.element?)
      raise ParseError.new("DOAP repository has no repository type") unless repository
      raise ParseError.new("Invalid DOAP repository namespace") unless DOAP.namespace(repository) == DOAP_NS

      value = new(kind: repository.name)
      repository.children.select(&.element?).each do |child|
        next unless DOAP.namespace(child) == DOAP_NS

        case child.name
        when "browse"   then value.browse = DOAP.resource(child)
        when "location" then value.location = DOAP.resource(child)
        end
      end
      value
    end

    def to_xml(xml : XML::Builder) : Nil
      xml.element("repository") do
        xml.element(kind) do
          xml.element("browse", {"rdf:resource" => browse.not_nil!}) if browse
          xml.element("location", {"rdf:resource" => location.not_nil!}) if location
        end
      end
    end
  end

  class Release
    property revision : String?
    property created : String?
    property file : String?

    def initialize(
      @revision : String? = nil,
      @created : String? = nil,
      @file : String? = nil,
    )
    end

    def self.from_xml(node : XML::Node) : self
      version = node.children.find(&.element?)
      raise ParseError.new("DOAP release has no Version element") unless version
      unless DOAP.namespace(version) == DOAP_NS && version.name == "Version"
        raise ParseError.new("Expected DOAP Version")
      end

      value = new
      version.children.select(&.element?).each do |child|
        next unless DOAP.namespace(child) == DOAP_NS

        case child.name
        when "revision"     then value.revision = child.content
        when "created"      then value.created = child.content
        when "file-release" then value.file = DOAP.resource(child)
        end
      end
      value
    end

    def to_xml(xml : XML::Builder) : Nil
      xml.element("release") do
        xml.element("Version") do
          xml.element("revision") { xml.text revision.not_nil! } if revision
          xml.element("created") { xml.text created.not_nil! } if created
          xml.element("file-release", {"rdf:resource" => file.not_nil!}) if file
        end
      end
    end
  end

  class Project
    property about : String?
    property name : String
    property created : String?
    getter short_descriptions : Array(LocalizedText)
    getter descriptions : Array(LocalizedText)
    property homepage : String?
    property documentation : String?
    property download_page : String?
    property bug_database : String?
    property developer_forum : String?
    property support_forum : String?
    property license : String?
    property logo : String?
    property screenshot : String?
    getter languages : Array(String)
    getter programming_languages : Array(String)
    getter operating_systems : Array(String)
    getter categories : Array(String)
    getter repositories : Array(Repository)
    getter specifications : Array(String)
    getter supported_xeps : Array(SupportedXep)
    getter releases : Array(Release)

    def initialize(
      @name : String,
      @about : String? = nil,
      @created : String? = nil,
      @short_descriptions : Array(LocalizedText) = [] of LocalizedText,
      @descriptions : Array(LocalizedText) = [] of LocalizedText,
      @homepage : String? = nil,
      @documentation : String? = nil,
      @download_page : String? = nil,
      @bug_database : String? = nil,
      @developer_forum : String? = nil,
      @support_forum : String? = nil,
      @license : String? = nil,
      @logo : String? = nil,
      @screenshot : String? = nil,
      @languages : Array(String) = [] of String,
      @programming_languages : Array(String) = [] of String,
      @operating_systems : Array(String) = [] of String,
      @categories : Array(String) = [] of String,
      @repositories : Array(Repository) = [] of Repository,
      @specifications : Array(String) = [] of String,
      @supported_xeps : Array(SupportedXep) = [] of SupportedXep,
      @releases : Array(Release) = [] of Release,
    )
      raise ArgumentError.new("name cannot be empty") if @name.blank?
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def self.from_xml(node : XML::Node) : self
      unless DOAP.namespace(node) == DOAP_NS && node.name == "Project"
        raise ParseError.new("Expected DOAP Project")
      end

      name_node = node.children.find do |child|
        child.element? && DOAP.namespace(child) == DOAP_NS && child.name == "name"
      end
      raise ParseError.new("DOAP Project is missing a name") unless name_node && !name_node.content.blank?

      project = new(name: name_node.content, about: DOAP.about(node))
      node.children.select(&.element?).each do |child|
        namespace = DOAP.namespace(child)

        if namespace == SCHEMA_NS
          case child.name
          when "documentation" then project.documentation = DOAP.resource(child)
          when "logo"          then project.logo = DOAP.resource(child)
          when "screenshot"    then project.screenshot = DOAP.resource(child)
          end
          next
        end
        next unless namespace == DOAP_NS

        case child.name
        when "name"                 then project.name = child.content
        when "created"              then project.created = child.content
        when "shortdesc"            then project.short_descriptions << DOAP.localized_text(child)
        when "description"          then project.descriptions << DOAP.localized_text(child)
        when "homepage"             then project.homepage = DOAP.resource(child)
        when "download-page"        then project.download_page = DOAP.resource(child)
        when "bug-database"         then project.bug_database = DOAP.resource(child)
        when "developer-forum"      then project.developer_forum = DOAP.resource(child)
        when "support-forum"        then project.support_forum = DOAP.resource(child)
        when "license"              then project.license = DOAP.resource(child)
        when "language"             then project.languages << child.content
        when "programming-language" then project.programming_languages << child.content
        when "os"                   then project.operating_systems << child.content
        when "category"
          if resource = DOAP.resource(child)
            project.categories << resource
          end
        when "repository"
          project.repositories << Repository.from_xml(child)
        when "implements"
          if resource = DOAP.resource(child)
            project.specifications << resource
          elsif supported_xep = child.children.find do |nested|
                  nested.element? && DOAP.namespace(nested) == XMPP_NS && nested.name == "SupportedXep"
                end
            project.supported_xeps << SupportedXep.from_xml(supported_xep)
          end
        when "release"
          project.releases << Release.from_xml(child)
        end
      end

      project
    end

    def to_xml(xml : XML::Builder) : Nil
      attributes = {} of String => String
      attributes["rdf:about"] = about.not_nil! if about

      xml.element("Project", attributes) do
        xml.element("name") { xml.text name }
        xml.element("created") { xml.text created.not_nil! } if created
        write_localized(xml, "shortdesc", short_descriptions)
        write_localized(xml, "description", descriptions)
        write_resource(xml, "homepage", homepage)
        write_resource(xml, "schema:documentation", documentation)
        write_resource(xml, "download-page", download_page)
        write_resource(xml, "bug-database", bug_database)
        write_resource(xml, "developer-forum", developer_forum)
        write_resource(xml, "support-forum", support_forum)
        write_resource(xml, "license", license)
        write_resource(xml, "schema:logo", logo)
        write_resource(xml, "schema:screenshot", screenshot)
        languages.each { |value| xml.element("language") { xml.text value } }
        programming_languages.each { |value| xml.element("programming-language") { xml.text value } }
        operating_systems.each { |value| xml.element("os") { xml.text value } }
        categories.each { |value| xml.element("category", {"rdf:resource" => value}) }
        repositories.each(&.to_xml(xml))
        specifications.each { |value| xml.element("implements", {"rdf:resource" => value}) }
        supported_xeps.each(&.to_xml(xml))
        releases.each(&.to_xml(xml))
      end
    end

    private def write_localized(xml : XML::Builder, name : String, values : Array(LocalizedText)) : Nil
      values.each do |value|
        attributes = {} of String => String
        attributes["xml:lang"] = value.language.not_nil! if value.language
        xml.element(name, attributes) { xml.text value.value }
      end
    end

    private def write_resource(xml : XML::Builder, name : String, value : String?) : Nil
      xml.element(name, {"rdf:resource" => value}) if value
    end
  end

  class Document
    getter projects : Array(Project)

    def initialize(@projects : Array(Project) = [] of Project)
    end

    def self.parse(xml : String) : self
      parsed = XML.parse(xml, XML::ParserOptions::NONET)
      root = parsed.first_element_child
      unless root && DOAP.namespace(root) == RDF_NS && root.name == "RDF"
        raise ParseError.new("Expected rdf:RDF document")
      end

      projects = root.children.select do |child|
        child.element? && DOAP.namespace(child) == DOAP_NS && child.name == "Project"
      end.map { |node| Project.from_xml(node) }

      raise ParseError.new("RDF document contains no DOAP Project") if projects.empty?
      new(projects)
    rescue error : XML::Error
      raise ParseError.new("Invalid DOAP XML: #{error.message}")
    end

    def self.parse(io : IO) : self
      parse(io.gets_to_end)
    end

    def to_xml : String
      XML.build(indent: "  ") do |xml|
        xml.element("rdf:RDF", {
          "xmlns:rdf"    => RDF_NS,
          "xmlns"        => DOAP_NS,
          "xmlns:xmpp"   => XMPP_NS,
          "xmlns:schema" => SCHEMA_NS,
        }) do
          projects.each(&.to_xml(xml))
        end
      end
    end
  end

  def self.namespace(node : XML::Node) : String
    node.namespace.try(&.href) || ""
  end

  def self.resource(node : XML::Node) : String?
    node.attributes.find do |attribute|
      attribute.name == "resource" && attribute.namespace.try(&.href) == RDF_NS
    end.try(&.content)
  end

  def self.about(node : XML::Node) : String?
    node.attributes.find do |attribute|
      attribute.name == "about" && attribute.namespace.try(&.href) == RDF_NS
    end.try(&.content)
  end

  def self.language(node : XML::Node) : String?
    current = node.as(XML::Node?)
    while current
      if attribute = current.attributes.find do |candidate|
           candidate.name == "lang" && candidate.namespace.try(&.href) == XML_NS
         end
        return attribute.content
      end
      current = current.parent
    end
    nil
  end

  def self.localized_text(node : XML::Node) : LocalizedText
    LocalizedText.new(node.content, language(node))
  end
end
