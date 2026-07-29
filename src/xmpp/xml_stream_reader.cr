require "./event_manager"

module XMPP
  class StreamParseError < ProtocolError; end

  class StanzaTooLarge < StreamParseError; end

  # Incrementally frames top-level XML elements from an XMPP byte stream.
  #
  # XMPP streams are intentionally not complete XML documents: the opening
  # <stream:stream> remains open for the lifetime of the connection. This
  # reader extracts that opening tag and every following top-level element
  # while retaining partial and coalesced reads in an internal buffer.
  class XMLStreamReader
    DEFAULT_MAX_ELEMENT_SIZE = 1_048_576
    DEFAULT_READ_SIZE        =      4096
    STRICT_XML_OPTIONS       = XML::ParserOptions::NONET

    def initialize(
      @io : IO,
      @max_element_size : Int32 = DEFAULT_MAX_ELEMENT_SIZE,
      @read_size : Int32 = DEFAULT_READ_SIZE,
    )
      raise ArgumentError.new("max_element_size must be positive") unless @max_element_size > 0
      raise ArgumentError.new("read_size must be positive") unless @read_size > 0

      @buffer = IO::Memory.new
      @buffer_start = 0
      @read_buffer = Bytes.new(Math.min(@read_size, @max_element_size))
      @namespaces = Hash(String, String).new
    end

    def read_node : XML::Node
      fragment, stream_open = read_fragment
      document_xml = if stream_open
                       "#{fragment}</stream:stream>"
                     elsif @namespaces.empty?
                       fragment
                     else
                       "<xmpp-root#{namespace_attributes}>#{fragment}</xmpp-root>"
                     end

      document = XML.parse(document_xml, STRICT_XML_OPTIONS)
      root = document.first_element_child || raise StreamParseError.new("XMPP element is empty")
      if stream_open
        root.namespaces.each do |prefix, href|
          @namespaces[prefix] = href if href
        end
        root
      elsif root.name == "xmpp-root"
        root.first_element_child || raise StreamParseError.new("XMPP element is empty")
      else
        root
      end
    rescue ex : XML::Error
      raise StreamParseError.new("Invalid XML received from XMPP stream: #{ex.message}")
    end

    private def read_fragment : Tuple(String, Bool)
      discard_prolog_and_whitespace
      extract_element
    end

    private def read_more
      buffered = buffered_bytes
      raise StanzaTooLarge.new("XMPP element exceeds #{@max_element_size} bytes") if buffered >= @max_element_size

      compact_buffer if @buffer_start > 0
      remaining = @max_element_size - buffered
      target = @read_buffer[0, Math.min(@read_buffer.size, remaining)]
      count = @io.read(target)
      raise ConnectionClosed.new("connection closed") if count == 0

      @buffer.write(target[0, count])
    end

    private def discard_prolog_and_whitespace
      loop do
        ensure_buffered(1)
        whitespace = 0
        while whitespace < buffered_bytes && ascii_whitespace?(byte_at(whitespace))
          whitespace += 1
        end
        consume(whitespace)
        ensure_buffered(1)

        ensure_buffered(2) if starts_with?("<")
        if starts_with?("<?")
          finish = find_sequence_end("?>", 2)
          consume(finish + 2)
        elsif starts_with?("<!")
          ensure_buffered(4)
          return unless starts_with?("<!--")
          finish = find_sequence_end("-->", 4)
          consume(finish + 3)
        else
          return
        end
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def extract_element : Tuple(String, Bool)
      raise StreamParseError.new("Unexpected text outside XMPP element") unless starts_with?("<")
      ensure_buffered(2)
      if starts_with?("</")
        closing_end = find_tag_end(0)
        closing_name = element_name(0, closing_end)
        raise ConnectionClosed.new("XMPP stream closed") if closing_name == "stream:stream"
        raise StreamParseError.new("Unexpected closing element </#{closing_name}> outside XMPP element")
      end
      if starts_with?("<!")
        ensure_buffered(9)
        if starts_with?("<!DOCTYPE")
          raise StreamParseError.new("DTD declarations are not allowed in XMPP streams")
        end
        raise StreamParseError.new("Unsupported XML declaration in XMPP stream")
      end

      first_end = find_tag_end(0)

      opening_name = element_name(0, first_end)
      stream_open = opening_name == "stream:stream"
      if stream_open || self_closing?(0, first_end)
        opening = slice_string(0, first_end + 1)
        consume(first_end + 1)
        return {opening, stream_open}
      end

      names = [opening_name]
      cursor = first_end + 1
      until names.empty?
        tag_start = find_byte('<'.ord.to_u8, cursor)
        ensure_buffered(tag_start + 2)

        if starts_with?("<?", tag_start)
          finish = find_sequence_end("?>", tag_start + 2)
          cursor = finish + 2
          next
        end

        if starts_with?("<!", tag_start)
          ensure_buffered(tag_start + 4)
          if starts_with?("<!--", tag_start)
            finish = find_sequence_end("-->", tag_start + 4)
            cursor = finish + 3
            next
          end

          ensure_buffered(tag_start + 9)
          if starts_with?("<![CDATA[", tag_start)
            finish = find_sequence_end("]]>", tag_start + 9)
            cursor = finish + 3
            next
          end
          if starts_with?("<!DOCTYPE", tag_start)
            raise StreamParseError.new("DTD declarations are not allowed in XMPP streams")
          end
          raise StreamParseError.new("Unsupported XML declaration in XMPP stream")
        end

        tag_end = find_tag_end(tag_start)

        if starts_with?("</", tag_start)
          closing_name = element_name(tag_start, tag_end)
          expected_name = names.pop
          unless closing_name == expected_name
            raise StreamParseError.new(
              "Mismatched XMPP closing element </#{closing_name}>; expected </#{expected_name}>"
            )
          end
        elsif !starts_with?("<!", tag_start) && !self_closing?(tag_start, tag_end)
          names << element_name(tag_start, tag_end)
        end
        cursor = tag_end + 1
      end

      fragment = slice_string(0, cursor)
      consume(cursor)
      {fragment, false}
    end

    private def find_tag_end(start : Int32) : Int32
      quote = nil.as(UInt8?)
      index = start + 1
      loop do
        while index < buffered_bytes
          byte = byte_at(index)
          if quote
            quote = nil if byte == quote
          elsif byte == '\''.ord || byte == '"'.ord
            quote = byte
          elsif byte == '>'.ord
            return index
          end
          index += 1
        end
        read_more
      end
    end

    private def find_byte(byte : UInt8, offset : Int32) : Int32
      index = offset
      loop do
        while index < buffered_bytes
          return index if byte_at(index) == byte
          index += 1
        end
        read_more
      end
    end

    private def find_sequence_end(needle : String, offset : Int32) : Int32
      search_from = offset
      loop do
        if found = index_of(needle, search_from)
          return found
        end
        search_from = Math.max(offset, buffered_bytes - needle.bytesize + 1)
        read_more
      end
    end

    private def ensure_buffered(required : Int32)
      while buffered_bytes < required
        read_more
      end
    end

    private def element_name(start : Int32, tag_end : Int32) : String
      index = start + 1
      index += 1 if byte_at(index) == '/'.ord
      finish = index
      while finish < tag_end
        byte = byte_at(finish)
        break if ascii_whitespace?(byte) || byte == '>'.ord || byte == '/'.ord
        finish += 1
      end
      raise StreamParseError.new("XMPP element has no name") if finish == index
      slice_string(index, finish - index)
    end

    private def self_closing?(tag_start : Int32, tag_end : Int32) : Bool
      index = tag_end - 1
      while index > tag_start && ascii_whitespace?(byte_at(index))
        index -= 1
      end
      index > tag_start && byte_at(index) == '/'.ord
    end

    private def ascii_whitespace?(byte : UInt8) : Bool
      byte == 0x20 || byte == 0x09 || byte == 0x0a || byte == 0x0d
    end

    private def consume(bytes : Int32)
      @buffer_start += bytes
      if @buffer_start == @buffer.size
        @buffer.clear
        @buffer_start = 0
      end
    end

    private def compact_buffer
      remaining = buffered_bytes
      compacted = IO::Memory.new
      compacted.write(@buffer.to_slice[@buffer_start, remaining]) if remaining > 0
      @buffer = compacted
      @buffer_start = 0
    end

    private def buffered_bytes : Int32
      @buffer.size - @buffer_start
    end

    private def buffer_empty? : Bool
      buffered_bytes == 0
    end

    private def byte_at(index : Int32) : UInt8
      @buffer.to_slice[@buffer_start + index]
    end

    private def slice_string(start : Int32, size : Int32) : String
      String.new(@buffer.to_slice[@buffer_start + start, size])
    end

    private def starts_with?(needle : String, offset = 0) : Bool
      return false if offset < 0 || needle.bytesize > buffered_bytes - offset
      needle.to_slice.each_with_index do |byte, index|
        return false unless byte_at(offset + index) == byte
      end
      true
    end

    private def index_of(byte : UInt8, offset = 0) : Int32?
      index = offset
      while index < buffered_bytes
        return index if byte_at(index) == byte
        index += 1
      end
      nil
    end

    private def index_of(needle : String, offset = 0) : Int32?
      return offset if needle.empty?
      last_start = buffered_bytes - needle.bytesize
      index = offset
      while index <= last_start
        return index if starts_with?(needle, index)
        index += 1
      end
      nil
    end

    private def namespace_attributes : String
      String.build do |attributes|
        @namespaces.each do |prefix, href|
          attributes << " " << prefix << "='" << escape_attribute(href) << "'"
        end
      end
    end

    private def escape_attribute(value : String) : String
      value.gsub("&", "&amp;").gsub("'", "&apos;").gsub("<", "&lt;")
    end
  end
end
