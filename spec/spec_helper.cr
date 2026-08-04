require "spec"
require "../src/cr-xmpp"

# Spins up a fake in-process DNS server answering SRV queries with the given
# records (matching by query name), returning the UDP port it bound to.
def srv_dns_server(records : Array(Tuple(String, UInt16, UInt16, UInt16, String)), query_name : String)
  server = UDPSocket.new
  server.bind "127.0.0.1", 0
  port = server.local_address.port

  spawn do
    loop do
      data, client = server.receive(4096)
      io = IO::Memory.new data
      id = io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      qdcount = io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)

      # Extract the query name to answer only matching records.
      qname = parse_query_name(io)
      io.pos = 12

      matching = records.select { |record| record[0] == qname }

      # Build response.
      resp = IO::Memory.new
      resp.write_bytes id, IO::ByteFormat::NetworkEndian
      resp.write_bytes 0x8180_u16, IO::ByteFormat::NetworkEndian # QR + RD + RA
      resp.write_bytes qdcount, IO::ByteFormat::NetworkEndian
      resp.write_bytes matching.size.to_u16, IO::ByteFormat::NetworkEndian
      resp.write_bytes 0_u16, IO::ByteFormat::NetworkEndian
      resp.write_bytes 0_u16, IO::ByteFormat::NetworkEndian

      # Echo question.
      resp.write io.to_slice[io.pos, data.size - io.pos]

      # Answers: name pointer to offset 12 (the question name), then SRV rdata.
      matching.each do |record|
        _, priority, weight, rport, target = record
        resp.write_byte 0xC0_u8
        resp.write_byte 12_u8
        resp.write_bytes 33_u16, IO::ByteFormat::NetworkEndian   # SRV
        resp.write_bytes 1_u16, IO::ByteFormat::NetworkEndian    # IN
        resp.write_bytes 3600_u32, IO::ByteFormat::NetworkEndian # TTL
        rdlength_pos = resp.pos
        resp.write_bytes 0_u16, IO::ByteFormat::NetworkEndian # rdlength (patched below)
        priority_bytes = IO::Memory.new
        priority_bytes.write_bytes priority, IO::ByteFormat::NetworkEndian
        priority_bytes.write_bytes weight, IO::ByteFormat::NetworkEndian
        priority_bytes.write_bytes rport, IO::ByteFormat::NetworkEndian
        target.split('.').each do |label|
          priority_bytes.write_byte label.size.to_u8
          priority_bytes << label
        end
        priority_bytes.write_byte 0_u8

        rdata = priority_bytes.to_slice
        resp.pos = rdlength_pos
        resp.write_bytes rdata.size.to_u16, IO::ByteFormat::NetworkEndian
        resp.pos = rdlength_pos + 2
        resp.write rdata
      end

      server.send resp.to_slice, client
    end
  rescue IO::Error
    # Server closed.
  end

  port
end

private def parse_query_name(io : IO::Memory) : String
  labels = [] of String
  loop do
    len = io.read_byte
    break if len.nil? || len == 0
    bytes = Bytes.new(len)
    io.read_fully(bytes)
    labels << String.new(bytes)
  end
  labels.join(".")
end
