require "./spec_helper"

describe "XEP-0453: DOAP usage in XMPP" do
  it "parses a minimal RDF/XML project description" do
    document = XMPP::DOAP::Document.parse(<<-XML)
      <?xml version='1.0' encoding='UTF-8'?>
      <rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'
               xmlns='http://usefulinc.com/ns/doap#'>
        <Project xml:lang='en'>
          <name>Poezio</name>
          <shortdesc>Free console XMPP client</shortdesc>
          <homepage rdf:resource='https://poez.io/'/>
          <os>Linux</os>
        </Project>
      </rdf:RDF>
      XML

    project = document.projects.first
    project.name.should eq "Poezio"
    project.short_descriptions.should eq [
      XMPP::DOAP::LocalizedText.new("Free console XMPP client", "en"),
    ]
    project.homepage.should eq "https://poez.io/"
    project.operating_systems.should eq ["Linux"]
  end

  it "parses XMPP-specific support records and common DOAP properties" do
    document = XMPP::DOAP::Document.parse(<<-XML)
      <rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'
               xmlns='http://usefulinc.com/ns/doap#'
               xmlns:xmpp='https://linkmauve.fr/ns/xmpp-doap#'
               xmlns:schema='https://schema.org/'>
        <Project rdf:about='https://example.com/project'>
          <name>Example</name>
          <created>2026-07-29</created>
          <shortdesc xml:lang='en'>An XMPP library</shortdesc>
          <shortdesc xml:lang='fr'>Une bibliothèque XMPP</shortdesc>
          <schema:documentation rdf:resource='https://docs.example.com/'/>
          <schema:logo rdf:resource='https://example.com/logo.svg'/>
          <programming-language>Crystal</programming-language>
          <category rdf:resource='https://linkmauve.fr/ns/xmpp-doap#category-library'/>
          <repository>
            <GitRepository>
              <browse rdf:resource='https://example.com/project'/>
              <location rdf:resource='https://example.com/project.git'/>
            </GitRepository>
          </repository>
          <implements rdf:resource='https://xmpp.org/rfcs/rfc6120.html'/>
          <implements>
            <xmpp:SupportedXep>
              <xmpp:xep rdf:resource='https://xmpp.org/extensions/xep-0030.html'/>
              <xmpp:status>partial</xmpp:status>
              <xmpp:version>2.5rc3</xmpp:version>
              <xmpp:since>0.5</xmpp:since>
              <xmpp:note xml:lang='en'>Queries are supported.</xmpp:note>
              <xmpp:note xml:lang='fr'>Les requêtes sont prises en charge.</xmpp:note>
            </xmpp:SupportedXep>
          </implements>
          <release>
            <Version>
              <revision>1.2.3</revision>
              <created>2026-07-29</created>
              <file-release rdf:resource='https://example.com/project-1.2.3.tar.gz'/>
            </Version>
          </release>
        </Project>
      </rdf:RDF>
      XML

    project = document.projects.first
    project.about.should eq "https://example.com/project"
    project.short_descriptions.should eq [
      XMPP::DOAP::LocalizedText.new("An XMPP library", "en"),
      XMPP::DOAP::LocalizedText.new("Une bibliothèque XMPP", "fr"),
    ]
    project.documentation.should eq "https://docs.example.com/"
    project.logo.should eq "https://example.com/logo.svg"
    project.programming_languages.should eq ["Crystal"]
    project.specifications.should eq ["https://xmpp.org/rfcs/rfc6120.html"]

    repository = project.repositories.first
    repository.kind.should eq "GitRepository"
    repository.location.should eq "https://example.com/project.git"

    supported_xep = project.supported_xeps.first
    supported_xep.xep.should eq "https://xmpp.org/extensions/xep-0030.html"
    supported_xep.status.should eq XMPP::DOAP::SupportStatus::Partial
    supported_xep.version.should eq "2.5rc3"
    supported_xep.since.should eq "0.5"
    supported_xep.notes.size.should eq 2

    release = project.releases.first
    release.revision.should eq "1.2.3"
    release.file.should eq "https://example.com/project-1.2.3.tar.gz"
  end

  it "serializes a project and round-trips its support data" do
    project = XMPP::DOAP::Project.new(
      name: "cr-xmpp",
      about: "https://github.com/naqvis/cr-xmpp",
      homepage: "https://github.com/naqvis/cr-xmpp",
      short_descriptions: [
        XMPP::DOAP::LocalizedText.new("An XMPP library", "en"),
      ],
      repositories: [
        XMPP::DOAP::Repository.new(
          browse: "https://github.com/naqvis/cr-xmpp",
          location: "https://github.com/naqvis/cr-xmpp.git"
        ),
      ],
      supported_xeps: [
        XMPP::DOAP::SupportedXep.new(
          "https://xmpp.org/extensions/xep-0453.html",
          XMPP::DOAP::SupportStatus::Complete,
          version: "0.1.2",
          since: "0.5.0",
          notes: [XMPP::DOAP::LocalizedText.new("RDF/XML support", "en")]
        ),
      ]
    )

    xml = XMPP::DOAP::Document.new([project]).to_xml
    reparsed = XMPP::DOAP::Document.parse(xml).projects.first
    supported_xep = reparsed.supported_xeps.first

    xml.should contain("xmlns:xmpp=\"https://linkmauve.fr/ns/xmpp-doap#\"")
    reparsed.name.should eq "cr-xmpp"
    reparsed.repositories.first.kind.should eq "GitRepository"
    supported_xep.status.should eq XMPP::DOAP::SupportStatus::Complete
    supported_xep.version.should eq "0.1.2"
    supported_xep.notes.first.language.should eq "en"
  end

  it "rejects missing required support properties and invalid statuses" do
    expect_raises(XMPP::DOAP::ParseError, /missing xmpp:status/) do
      XMPP::DOAP::Document.parse(<<-XML)
        <rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'
                 xmlns='http://usefulinc.com/ns/doap#'
                 xmlns:xmpp='https://linkmauve.fr/ns/xmpp-doap#'>
          <Project>
            <name>Example</name>
            <implements>
              <xmpp:SupportedXep>
                <xmpp:xep rdf:resource='https://xmpp.org/extensions/xep-0030.html'/>
              </xmpp:SupportedXep>
            </implements>
          </Project>
        </rdf:RDF>
        XML
    end

    expect_raises(XMPP::DOAP::ParseError, /Invalid XEP support status/) do
      XMPP::DOAP::SupportStatus.from_xml("unknown")
    end
  end
end
