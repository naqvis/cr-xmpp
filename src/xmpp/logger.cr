require "logger"

module XMPP::Logger
  @@logger = ::Logger.new(STDOUT, progname: "Crystal-XMPP")
  @@logger.level = ::Logger::INFO
  @@logger.formatter = ::Logger::Formatter.new do |severity, datetime, progname, message, io|
    label = severity.unknown? ? "ANY" : severity.to_s
    io << "[" << datetime << " #" << Process.pid << "] "
    io << label.rjust(5) << " -- " << progname << ": " << message
  end

  {% for method in %w(info debug warn fatal error) %}
      def self.{{method.id}}(*args)
        @@logger.{{method.id}}(*args)
      end
  {% end %}
end
