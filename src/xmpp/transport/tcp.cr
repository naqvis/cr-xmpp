require "socket"
require "./transport"

module XMPP
  # Classic RFC 6120 client transport over TCP. STARTTLS is negotiated by
  # `Session` on top of this transport; XEP-0368 direct TLS is pre-wrapped
  # here (mirroring the previous `Client#open_socket` behavior).
  class TcpTransport < Transport
    getter socket : TCPSocket
    getter tls_socket : OpenSSL::SSL::Socket::Client?

    def initialize(@socket : TCPSocket, @tls_socket : OpenSSL::SSL::Socket::Client? = nil)
    end

    def self.open(config : Config) : TcpTransport
      endpoints = ConnectionResolver.resolve(config)
      last_error = nil.as(Exception?)
      endpoints.each do |endpoint|
        begin
          tcp = TCPSocket.new(endpoint.host, endpoint.port, connect_timeout: config.connect_timeout)
          tcp.tcp_keepalive_interval = 30
          tcp.read_timeout = config.io_timeout.seconds
          tcp.write_timeout = config.io_timeout.seconds
          tcp.sync = true
          if endpoint.mode.direct_tls?
            tls = TLSConnection.wrap(tcp, config, endpoint.host)
            return new(tcp, tls)
          end
          return new(tcp)
        rescue ex
          Logger.warn "Connection to #{endpoint.host}:#{endpoint.port} failed: #{ex.message}"
          last_error = ex
        end
      end
      raise ConnectionError.new("unable to connect to any XMPP endpoint#{last_error ? ": #{last_error.message}" : ""}")
    end

    def read(slice : Bytes) : Int32
      io.read(slice)
    end

    def write(slice : Bytes) : Nil
      io.write(slice)
    end

    def close
      @tls_socket.try { |tls| tls.close unless tls.closed? }
      @socket.close unless @socket.closed?
    end

    def closed? : Bool
      (@tls_socket || @socket).closed?
    end

    def encrypted? : Bool
      !@tls_socket.nil?
    end

    def supports_starttls? : Bool
      true
    end

    private def io : ::IO
      @tls_socket || @socket
    end
  end
end
