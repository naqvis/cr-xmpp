module XMPP
  # XEP-0114: Jabber Component Protocol - Error Handling

  # Base exception for component errors
  class ComponentError < Exception
  end

  # XEP-0114: Conflict error
  # The component JID is already connected
  class ComponentConflictError < ComponentError
    def initialize(message = "Component JID is already connected")
      super(message)
    end
  end

  # XEP-0114: Host unknown error
  # The hostname is not recognized by the server
  class ComponentHostUnknownError < ComponentError
    def initialize(host : String)
      super("Host '#{host}' is not recognized by the server")
    end
  end

  # XEP-0114: Authentication failed
  class ComponentAuthenticationError < ComponentError
    def initialize(message = "Component authentication failed")
      super(message)
    end
  end

  # XEP-0114: Invalid namespace
  class ComponentInvalidNamespaceError < ComponentError
    def initialize(message = "Invalid namespace in component stream")
      super(message)
    end
  end

  # Generic stream error for components
  class ComponentStreamError < ComponentError
    property error_type : String

    def initialize(@error_type : String, message : String? = nil)
      super(message || "Component stream error: #{@error_type}")
    end
  end
end
