require "http/client"
require "json"
require "xml"
require "./config"
require "./tls"

module XMPP
  # The kind of alternative connection endpoint discovered via XEP-0156.
  enum EndpointKind
    WebSocket
    Bosh
  end

  record AlternativeEndpoint, kind : EndpointKind, url : URI

  # XEP-0156 (v1.4.0): discovers WebSocket and BOSH endpoints from the
  # HTTPS host-meta document (XRD XML or JRD JSON). The DNS _xmppconnect TXT
  # method was removed from the spec and is deliberately not implemented.
  module AltConnectionResolver
    extend self

    WEBSOCKET_REL = "urn:xmpp:alt-connections:websocket"
    BOSH_REL      = "urn:xmpp:alt-connections:xbosh"
    XRD_PATH      = "/.well-known/host-meta"
    JRD_PATH      = "/.well-known/host-meta.json"

    # Discovers alternative endpoints, ordered WebSocket before BOSH and
    # wss/https before ws/http. Fetches the XRD document first and falls back
    # to JRD when XRD yields no alt-connection links.
    def discover(
      domain : String,
      config : Config? = nil,
      fetcher : (String) -> String? = ->(url : String) { https_get(url, config) },
    ) : Array(AlternativeEndpoint)
      xrd = fetcher.call("https://#{domain}#{XRD_PATH}")
      links = parse_xrd(xrd, domain)
      if links.empty?
        jrd = fetcher.call("https://#{domain}#{JRD_PATH}")
        links = parse_jrd(jrd, domain)
      end
      filter_and_order(links)
    end

    # Fetches a URL over HTTPS with normal certificate verification (honoring
    # the configured CA bundle). Returns nil on any transport or TLS failure.
    def https_get(url : String, config : Config? = nil) : String?
      uri = URI.parse(url)
      tls = config ? TLSConnection.client_context(config.not_nil!) : true
      client = HTTP::Client.new(uri.host.not_nil!, uri.port, tls: tls)
      client.connect_timeout = 5.seconds
      response = client.get(uri.request_target || "/")
      response.status.success? ? response.body : nil
    rescue Socket::Error | IO::Error | OpenSSL::SSL::Error
      nil
    ensure
      client.try(&.close)
    end

    private def parse_xrd(xml : String?, domain : String) : Array(AlternativeEndpoint)
      return [] of AlternativeEndpoint unless xml
      root = XML.parse(xml).first_element_child
      return [] of AlternativeEndpoint unless root && root.name == "XRD"
      root.children.select(&.element?).compact_map do |child|
        next nil unless child.name == "Link"
        rel = child["rel"]?
        href = child["href"]?
        kind = rel ? kind_for(rel) : nil
        if kind && href && valid_url?(href)
          AlternativeEndpoint.new(kind, URI.parse(href))
        end
      end
    rescue XML::Error
      [] of AlternativeEndpoint
    end

    private def parse_jrd(json : String?, domain : String) : Array(AlternativeEndpoint)
      return [] of AlternativeEndpoint unless json
      links = JSON.parse(json)["links"]?
      return [] of AlternativeEndpoint unless links
      links.as_a.compact_map do |link|
        rel = link["rel"]?.try(&.as_s)
        href = link["href"]?.try(&.as_s)
        kind = rel ? kind_for(rel) : nil
        if kind && href && valid_url?(href)
          AlternativeEndpoint.new(kind, URI.parse(href))
        end
      end
    rescue JSON::ParseException
      [] of AlternativeEndpoint
    end

    private def kind_for(rel : String) : EndpointKind?
      case rel
      when WEBSOCKET_REL then EndpointKind::WebSocket
      when BOSH_REL      then EndpointKind::Bosh
      end
    end

    private def valid_url?(url : String) : Bool
      uri = URI.parse(url)
      uri.scheme.in?("ws", "wss", "http", "https") && !uri.host.nil?
    end

    private def filter_and_order(endpoints : Array(AlternativeEndpoint)) : Array(AlternativeEndpoint)
      endpoints.sort_by do |endpoint|
        kind_rank = endpoint.kind.web_socket? ? 0 : 1
        scheme_rank = endpoint.url.scheme.in?("wss", "https") ? 0 : 1
        {kind_rank, scheme_rank}
      end
    end
  end
end
