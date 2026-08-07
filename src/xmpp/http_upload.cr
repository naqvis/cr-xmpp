require "./client"
require "./stanza"
require "http/client"

module XMPP
  # HTTPUpload is a high-level client for XEP-0363 - HTTP File Upload.
  #
  # A server-provided upload service (discovered via disco#info on the
  # service JID) grants a temporary slot: a PUT URL to push the file data to
  # over HTTPS and a GET URL others can later fetch it from.
  #
  #   uploader = XMPP::HTTPUpload.new(client, "upload.example.org")
  #   return unless uploader.supported?
  #   url = uploader.upload("photo.jpg", File.size(path), "image/jpeg", File.open(path))
  #
  # See: https://xmpp.org/extensions/xep-0363.html
  class HTTPUpload
    # Disco feature advertised by upload services.
    NS_HTTP_UPLOAD = "urn:xmpp:http:upload:0"

    def initialize(@client : Client, @service : String)
    end

    # supported? queries the upload service for support and returns true when
    # the urn:xmpp:http:upload:0 feature is advertised.
    def supported?(timeout : Time::Span = 5.seconds) : Bool
      iq = build_iq("get", Stanza::DiscoInfo.new, @service)
      response = @client.request(iq, timeout)
      return false unless response && response.type == "result"
      info = response.payload.as?(Stanza::DiscoInfo)
      return false unless info
      info.features.any? { |feature| feature.var == NS_HTTP_UPLOAD }
    end

    # request_slot asks the service for a slot for a file of the given size
    # and content type and returns the granted slot (nil on error/timeout).
    def request_slot(
      filename : String,
      size : UInt64,
      content_type : String,
      timeout : Time::Span = 5.seconds,
    ) : Stanza::Slot?
      req = Stanza::UploadRequest.new
      req.filename = filename
      req.size = size
      req.content_type = content_type

      response = @client.request(build_iq("get", req, @service), timeout)
      return nil unless response && response.type == "result"
      response.payload.as?(Stanza::Slot)
    end

    # upload requests a slot for the file and PUTs the given data to the
    # granted URL over HTTPS. On a successful upload (HTTP 2xx) the GET URL is
    # returned; nil is returned on failure.
    def upload(
      filename : String,
      size : UInt64,
      content_type : String,
      data : IO,
      timeout : Time::Span = 5.seconds,
    ) : String?
      slot = request_slot(filename, size, content_type, timeout)
      return nil unless slot
      put_data(slot, content_type, data, timeout) ? slot.get_url : nil
    end

    # upload is a convenience overload accepting the payload as a String.
    def upload(
      filename : String,
      size : UInt64,
      content_type : String,
      data : String,
      timeout : Time::Span = 5.seconds,
    ) : String?
      upload(filename, size, content_type, IO::Memory.new(data), timeout)
    end

    private def put_data(
      slot : Stanza::Slot,
      content_type : String,
      data : IO,
      timeout : Time::Span,
    ) : Bool
      return false if slot.put_url.blank?
      uri = URI.parse(slot.put_url)
      client = HTTP::Client.new(uri)
      client.connect_timeout = timeout
      client.read_timeout = timeout
      begin
        headers = HTTP::Headers.new
        slot.put_headers.each { |header| headers[header.name] = header.value }
        headers["Content-Type"] = content_type
        response = client.put(uri.request_target, headers: headers, body: data)
        response.success?
      rescue IO::Error
        false
      ensure
        client.close
      end
    end

    private def build_iq(type : String, payload : Stanza::IQPayload, to : String)
      iq = Stanza::IQ.new
      iq.type = type
      iq.to = to
      iq.payload = payload
      iq
    end
  end
end
