require "socket"

module XMPP
  # Minimal DNS SRV (RFC 2782) resolver used by XEP-0368 connection
  # discovery. Crystal's stdlib resolves only A/AAAA records via
  # Socket::Addrinfo, so this hand-rolled resolver issues a UDP SRV query
  # through the system resolver configured in /etc/resolv.conf.
  module DnsSrv
    # A single SRV resource record.
    record SRVRecord, priority : UInt16, weight : UInt16, port : UInt16, target : String

    private RECORD_SRV = 33_u16
    private CLASS_IN   =  1_u16
    private TYPE_A     =  1_u16
    private TYPE_CNAME =  5_u16
    private DNS_PORT   = 53_u16

    # Test hook: overrides the nameservers used by resolve. When a server
    # includes an explicit ":port" suffix it is honored, which lets specs
    # point the resolver at an in-process fake DNS server.
    @@test_nameservers : Array(String)? = nil

    def self.stub_nameservers(servers : Array(String), &)
      previous = @@test_nameservers
      @@test_nameservers = servers
      begin
        yield
      ensure
        @@test_nameservers = previous
      end
    end

    # Resolves SRV records for the given service and domain.
    #
    # service is the underscore-prefixed service name, e.g. "_xmpps-client".
    # domain is the XMPP service domain, e.g. "example.org".
    #
    # Returns the records sorted by RFC 2782 priority, with weighted
    # randomization applied within equal priorities. Returns an empty array
    # when no records exist, the query fails, or no resolver is configured.
    def self.resolve(service : String, domain : String, timeout : Float64 = 2.0) : Array(SRVRecord)
      servers = nameservers
      return [] of SRVRecord if servers.empty?

      query = build_query "#{service}._tcp.#{domain}"
      socket = UDPSocket.new
      begin
        socket.read_timeout = timeout.seconds
        socket.write_timeout = timeout.seconds

        servers.each do |server|
          begin
            address = server_ip_address server
            next unless address
            socket.send(query, address)
            data, _from = socket.receive(4096)
            records = parse_response data.to_slice, query
            return sort_rfc2782 records unless records.empty?
          rescue ex : IO::Error | Socket::Error
            next
          end
        end
        [] of SRVRecord
      ensure
        socket.close
      end
    end

    private def self.server_ip_address(server : String) : Socket::IPAddress?
      host, _, port = server.rpartition(":")
      if host.blank?
        host = server
        port = DNS_PORT.to_s
      end
      port_i = port.to_i?
      return nil unless port_i && port_i > 0 && port_i <= 65535

      addresses = Socket::IPAddress.parse(host) rescue nil
      return addresses unless addresses.nil?

      begin
        addrs = Socket::Addrinfo.tcp host, port_i
        addrs.first.ip_address
      rescue
        nil
      end
    end

    # Reads the list of resolver addresses from /etc/resolv.conf. Returns
    # [] when the file is missing or has no usable nameserver entries.
    private def self.nameservers : Array(String)
      if (stub = @@test_nameservers) && !stub.nil?
        return stub
      end

      servers = [] of String
      begin
        File.each_line("/etc/resolv.conf") do |line|
          stripped = line.strip
          next if stripped.starts_with?('#')
          next unless stripped.starts_with?("nameserver")

          parts = stripped.split(/\s+/)
          next unless parts.size >= 2

          address = parts[1]
          # IPv6 literals appear as "nameserver ::1" without brackets.
          address = address.gsub(/[\[\]]/, "")
          servers << address
        end
      rescue File::NotFoundError
      end
      servers
    end

    # Builds a DNS query message for the given name and SRV type.
    private def self.build_query(name : String) : Bytes
      io = IO::Memory.new
      io.write_bytes 0x1234_u16, IO::ByteFormat::NetworkEndian
      io.write_bytes 0x0100_u16, IO::ByteFormat::NetworkEndian # recursion desired
      io.write_bytes 1_u16, IO::ByteFormat::NetworkEndian      # qdcount
      io.write_bytes 0_u16, IO::ByteFormat::NetworkEndian      # ancount
      io.write_bytes 0_u16, IO::ByteFormat::NetworkEndian      # nscount
      io.write_bytes 0_u16, IO::ByteFormat::NetworkEndian      # arcount

      write_name io, name
      io.write_bytes RECORD_SRV, IO::ByteFormat::NetworkEndian
      io.write_bytes CLASS_IN, IO::ByteFormat::NetworkEndian
      io.to_slice
    end

    private def self.write_name(io : IO::Memory, name : String)
      name.split('.').each do |label|
        raise ArgumentError.new("DNS label too long") if label.size > 63
        io.write_byte label.size.to_u8
        io << label
      end
      io.write_byte 0_u8
    end

    # Parses a DNS response, returning SRV records found in the answer
    # section. The original query is required to correlate CNAME targets
    # and to skip the echoed question section safely.
    private def self.parse_response(data : Bytes, query : Bytes) : Array(SRVRecord)
      io = IO::Memory.new data

      # Validate header: response bit, matching ID.
      id = io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      flags = io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      return [] of SRVRecord unless (flags & 0x8000) != 0
      return [] of SRVRecord unless id == 0x1234

      qdcount = io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      ancount = io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian) # nscount
      io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian) # arcount

      records = [] of SRVRecord
      cursor = Cursor.new(data)
      cursor.advance 12 # skip the header consumed above

      # Skip the question section; we already know the name and record type.
      qdcount.times do
        cursor.skip_name
        cursor.advance 4 # qtype + qclass
      end

      ancount.times do
        cursor.read_name
        rtype = cursor.read_u16
        cursor.advance 2 # class
        cursor.advance 4 # ttl
        rdlength = cursor.read_u16

        case rtype
        when RECORD_SRV
          if srv = parse_srv(cursor, rdlength)
            records << srv
          else
            cursor.advance rdlength
          end
        else
          cursor.advance rdlength
        end
      end

      records
    end

    private def self.parse_srv(cursor : Cursor, rdlength : UInt16) : SRVRecord?
      priority = cursor.read_u16
      weight = cursor.read_u16
      port = cursor.read_u16
      target = cursor.read_name
      return nil if target.blank?
      SRVRecord.new priority, weight, port, target
    end

    # Sorts SRV records per RFC 2782: by ascending priority, with weighted
    # randomization within a priority class.
    private def self.sort_rfc2782(records : Array(SRVRecord)) : Array(SRVRecord)
      records.group_by(&.priority).to_a.sort_by { |priority, _group| priority }.flat_map do |_priority, group|
        weighted_shuffle group
      end
    end

    # RFC 2782 weighted selection: iteratively pick records proportional to
    # their weight (zero-weight records are chosen uniformly first).
    private def self.weighted_shuffle(records : Array(SRVRecord)) : Array(SRVRecord)
      result = [] of SRVRecord
      pool = records.dup

      zero_weight = pool.select(&.weight.== 0)
      nonzero = pool.reject(&.weight.== 0)

      unless zero_weight.empty?
        result.concat zero_weight.shuffle
      end

      remaining = nonzero
      until remaining.empty?
        total = remaining.sum(&.weight.to_i32)
        if total <= 0
          result.concat remaining
          break
        end
        index = rand(0...total)
        running = 0
        chosen = -1
        remaining.each_with_index do |record, i|
          running += record.weight
          if index < running
            chosen = i
            break
          end
        end
        chosen = remaining.size - 1 if chosen < 0
        result << remaining[chosen]
        remaining.delete_at chosen
      end

      result
    end

    # A cursor over a DNS message supporting label compression (RFC 1035).
    private class Cursor
      getter pos : Int32

      def initialize(@data : Bytes)
        @pos = 0
      end

      def advance(n : Int32)
        @pos += n
      end

      def advance(n : UInt16)
        @pos += n
      end

      def read_u16 : UInt16
        a = @data[@pos].to_u16
        b = @data[@pos + 1].to_u16
        @pos += 2
        (a << 8) | b
      end

      def read_name : String
        labels = [] of String
        # Position to resume from after the name (first pointer, if any).
        continuation = -1

        loop do
          length = @data[@pos].to_u16
          if (length & 0xC0) == 0xC0
            pointer = (((length & 0x3F) << 8) | @data[@pos + 1].to_u16).to_i32
            if continuation < 0
              continuation = @pos + 2
              @pos = pointer
            else
              @pos = pointer
            end
          elsif length == 0
            @pos = continuation >= 0 ? continuation : @pos + 1
            break
          else
            label = String.new(@data[@pos + 1, length])
            labels << label
            @pos += length + 1
          end
        end

        labels.join('.')
      end

      def skip_name
        loop do
          length = @data[@pos].to_u16
          if (length & 0xC0) == 0xC0
            @pos += 2
            break
          elsif length == 0
            @pos += 1
            break
          else
            @pos += length + 1
          end
        end
      end
    end
  end
end
