require "log"

module XMPP::Logger
  @@logger : Log = build_logger

  private def self.build_logger(output = STDOUT)
    backend = Log::IOBackend.new(output)
    backend.progname = "Crystal-XMPP"
    backend.formatter = Log::Formatter.new do |entry, io|
      label = entry.severity.none? ? "ANY" : entry.severity.label
      io << "[" << entry.timestamp << " #" << Process.pid << "]"
      io << label.rjust(7) << " -- " << backend.progname << ": " << entry.message
    end

    builder = Log::Builder.new
    builder.bind("", :info, backend)
    builder.for("")
  end

  {% for method in %w(info debug warn fatal error) %}
      def self.{{method.id}}(msg)
        @@logger.{{method.id}} {msg}
      end
  {% end %}
end
