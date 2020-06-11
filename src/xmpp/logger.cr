require "log"

module XMPP::Logger
  @@logger : Log = build_logger

  Log.define_formatter MyFormat, "[#{timestamp} ##{Process.pid}] #{(severity || "ANY").rjust(7)} -- Crystal-XMPP: #{message}"

  private def self.build_logger(output = STDOUT)
    backend = Log::IOBackend.new(output, formatter: MyFormat)
    Log.setup(:info, backend)
    Log.for("Crystal-XMPP")
  end

  {% for method in %w(info debug warn fatal error) %}
      def self.{{method.id}}(msg)
        @@logger.{{method.id}} {msg}
      end
  {% end %}
end

