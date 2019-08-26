require "./xmpp"
require "./stanza"

module XMPP
  # The XMPP::Router helps client and component developers select which XMPP they would like to process,
  # and associate processing code depending on the router configuration.
  #
  # Here are important rules to keep in mind while setting your routes and matchers:
  # - Routes are evaluated in the order they are set.
  # - When a route matches, it is executed and all others routes are ignored. For each packet, only a single
  #  route is executed.
  # - An empty route will match everything. Adding an empty route as the last route in your router will
  #  allow you to get all stanzas that did not match any previous route. You can for example use this to
  #  log all unexpected stanza received by your client or component.
  #

  class Router
    # Routes to be matched, in order
    @routes : Array(Route)

    def initialize
      @routes = Array(Route).new
    end

    # route is called by the XMPP client to dispatch stanza received using the set up routes.
    # It is also used by test, but is not supposed to be used directly by users of the library.
    protected def route(s : Sender, p : Stanza::Packet)
      if (r = match(p))
        # If we match, route the packet
        r.call s, p
        return
      end
      # If there is no match and we receive an iq set or get, we need to send a reply
      if (iq = p.as?(Stanza::IQ))
        return iq_not_implemented(s, iq) if [Stanza::IQ_TYPE_GET, Stanza::IQ_TYPE_SET].includes? iq.type
      end
    end

    # route register an empty routes
    def route(&handler : Callback)
      r = Route.new(handler)
      @routes << r
      r
    end

    def route(handler : Callback)
      route(&handler)
    end

    def match(p : Stanza::Packet)
      @routes.each do |route|
        m = route.match(p)
        return m unless m.nil?
      end
      nil
    end

    # on registers a new route with a matcher for a given packet name (iq, message, presence)
    def on(name : String, &handler : Callback)
      route(&handler).packet(name)
    end

    def on(name : String, handler : Callback)
      on(name, &handler)
    end

    # when registers a new route with a matcher for a given packet type
    def when(*type : String, &handler : Callback)
      arr = Array(String).new
      type.each { |t| arr << t }
      route(&handler).stanza_type(arr)
    end

    def when(*type : String, handler : Callback)
      self.when(type, &handler)
    end

    {% for method in %w(iq message presence) %}
    def {{method.id}}(handler : Callback)
      on({{method}}, handler)
    end
    def {{method.id}}(&handler : Callback)
      on({{method}}, &handler)
    end
  {% end %}

    private def iq_not_implemented(s : Sender, iq : Stanza::IQ) : Nil
      err = Stanza::Error.new
      err.code = 501
      err.type = "cancel"
      err.reason = "feature-not-implemented"
      iq.make_error err
      s.send iq
    end

    # HandleFunc registers a new route with a matcher for for a given packet name (iq, message, presence)
    # See Route.Path() and Route.Callback().
    # def handler_func(name : String, &handler : Callback)
    #   route.packet(name).handler_func(handler)
    # end
  end

  class Route
    @cb : Callback
    # Matchers are used to "specialize" routes and focus on specific packet features
    @matchers : Array(Matcher)

    def initialize(@cb)
      @matchers = Array(Matcher).new
    end

    def add_matcher(m : Matcher)
      @matchers << m
    end

    def match(p : Stanza::Packet)
      @matchers.each do |m|
        return nil unless m.match(p)
      end
      # we have a match, let's pass info route match info
      @cb
    end

    # packet matches on a packet name (iq, message, presence, ...)
    # It matches on the Local part of the XMLName
    def packet(name : String)
      add_matcher(NameMatcher.new(name))
    end

    def stanza_type(types : Array(String))
      types.map! { |i| i.downcase }
      add_matcher NSTypeMatcher.new(types)
    end

    def iq_namespaces(namespaces : Array(String))
      namespaces.map! { |i| i.downcase }
      add_matcher NSIQMatcher.new(namespaces)
    end
  end

  # Matchers are used to "specialize" routes and focus on specific packet features
  private abstract class Matcher
    abstract def match(p : Stanza::Packet) : Bool
  end

  # Match on packet name
  private class NameMatcher < Matcher
    @name : String
    forward_missing_to @name

    def initialize(@name)
    end

    def match(p : Stanza::Packet) : Bool
      @name == p.name
    end
  end

  # Match on Stanza Type
  # NSTypeMatcher matches on a list of IQ payload namespaces
  private class NSTypeMatcher < Matcher
    @types : Array(String)

    def initialize(@types)
    end

    def match(p : Stanza::Packet) : Bool
      type = ""
      case p
      when .is_a? Stanza::IQ
        type = p.as(Stanza::IQ).type
      when .is_a? Stanza::Presence
        type = p.as(Stanza::Presence).type
      when .is_a? Stanza::Message
        type = p.as(Stanza::Message).type
        # optional on message, normal is the default type
        type = type.blank? ? "normal" : type
      else
        return false
      end
      return false if type.blank?
      @types.includes?(type)
    end
  end

  # Match on IQ and namespace
  # NSIQMatcher matches on a list of IQ payload namespaces
  private class NSIQMatcher < Matcher
    @types : Array(String)

    def initialize(@types)
    end

    def match(p : Stanza::Packet) : Bool
      return false unless p.is_a?(Stanza::IQ)
      iq = p.as(Stanza::IQ)
      if (payload = iq.payload)
        @types.includes? payload.namespace
      else
        false
      end
    end
  end
end
