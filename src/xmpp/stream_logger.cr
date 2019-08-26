module XMPP
  # Mediated Read/Write on socket
  # Used if logFile from Config is not nil

  private class StreamLogger < IO
    getter socket : IO # Actual connection
    getter log_file : IO?

    def initialize(@socket, @log_file = nil)
    end

    def read(slice : Bytes)
      n = @socket.read(slice)
      unless n == 0
        if (sp = @log_file)
          sp << "RECV:" << "\n" # Prefix
          sp << String.new(slice[0, n])
          sp << "\n\n" # Separator
        end
      end
      n
    end

    def write(slice : Bytes) : Nil
      @socket.write slice
      @socket.flush
      if (sp = @log_file)
        sp << "SEND:" << "\n" # Prefix
        sp << String.new(slice)
        sp << "\n\n" # Separator
      end
    end

    private def do_read(bytes : Slice)
      buff = Bytes.new(100)
      size = 0
      remaining = bytes.size
      retries = 0
      loop do
        if remaining < buff.size
          buff = buff[0...buff.size - remaining]
        end
        begin
          n = @socket.read(buff)
          unless n == 0
            bytes[size..].copy_from(buff.to_unsafe, n)
            size += n
            remaining -= n
            buff.to_unsafe.clear(n)
            break if (n < buff.size) || (remaining <= 0)
            next
          end
        rescue ex
          Logger.error "Got exception: #{ex.message}"
          Logger.info "So far : size = #{size}, remaining = #{remaining}, buff = #{String.new(bytes)}"
          retries += 1
          raise ex if retries > 3
          Logger.info "Retrying read #{retries} time"
          sleep 1
          next
          # raise ex
        end
        break
      end
      size
    end
  end
end
