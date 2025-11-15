require "../stanza"

module XMPP
  # XEP-0356: Privileged Entity - Component Side Implementation
  # Allows components to have privileged access to user data
  module ComponentPrivilege
    # Permission types for different access levels
    enum PermissionType
      None
      Get
      Set
      Both
      Outgoing # For messages
    end

    # Represents a single permission grant
    class Permission
      property access : String # "roster", "message", "iq", "presence"
      property type : PermissionType
      property? push : Bool                                   # For roster pushes
      property namespaces : Array(String) = Array(String).new # For IQ permissions

      def initialize(@access, @type, @push = false, @namespaces = [] of String)
      end

      def allows_get? : Bool
        type.get? || type.both?
      end

      def allows_set? : Bool
        type.set? || type.both?
      end

      def allows_outgoing? : Bool
        type.outgoing?
      end
    end

    # Manages privileges for a component
    class PrivilegeManager
      property permissions : Hash(String, Permission) = Hash(String, Permission).new

      # Add a permission
      def add_permission(access : String, type : PermissionType, push : Bool = false, namespaces : Array(String) = [] of String)
        @permissions[access] = Permission.new(access, type, push, namespaces)
        Logger.info "Privilege granted: #{access} (#{type})"
      end

      # Check if we have a specific permission
      def has_permission?(access : String) : Bool
        @permissions.has_key?(access)
      end

      # Get permission for an access type
      def get_permission(access : String) : Permission?
        @permissions[access]?
      end

      # Check roster permissions
      def can_get_roster? : Bool
        perm = @permissions["roster"]?
        perm ? perm.allows_get? : false
      end

      def can_set_roster? : Bool
        perm = @permissions["roster"]?
        perm ? perm.allows_set? : false
      end

      def receives_roster_pushes? : Bool
        perm = @permissions["roster"]?
        perm.try &.push? || false
      end

      # Check message permissions
      def can_send_messages? : Bool
        perm = @permissions["message"]?
        perm.try &.allows_outgoing? || false
      end

      # Check IQ permissions
      def can_send_iq?(namespace : String) : Bool
        perm = @permissions["iq"]?
        return false unless perm
        perm.namespaces.includes?(namespace)
      end

      # Check presence permissions
      def can_access_presence? : Bool
        @permissions.has_key?("presence")
      end
    end

    # Instance variables for privilege
    @privilege_manager : PrivilegeManager = PrivilegeManager.new

    def privilege_manager : PrivilegeManager
      @privilege_manager
    end

    # Handle privilege advertisement from server
    # Called when server sends <message> with <privilege> element
    def handle_privilege_advertisement(privilege_msg : Stanza::Message)
      privilege_msg.extensions.each do |ext|
        next unless ext.is_a?(Stanza::Privilege)

        privilege = ext.as(Stanza::Privilege)
        privilege.perms.each do |perm|
          parse_and_add_permission(perm)
        end
      end
    end

    # Parse and add a permission from a Perm stanza
    private def parse_and_add_permission(perm : Stanza::Perm)
      perm_type = PermissionType.parse(perm.type.capitalize) rescue PermissionType::None
      namespaces = perm.namespaces.map(&.value)

      @privilege_manager.add_permission(perm.access, perm_type, perm.push?, namespaces)
    end

    # Manually add a privilege (for testing or explicit configuration)
    def grant_privilege(access : String, type : String, push : Bool = false, namespaces : Array(String) = [] of String)
      perm_type = PermissionType.parse(type.capitalize) rescue PermissionType::None

      @privilege_manager.add_permission(access, perm_type, push, namespaces)
    end

    # Get a user's roster (requires roster get permission)
    # Returns the IQ ID for tracking the response
    def get_user_roster(user_jid : String) : String?
      unless @privilege_manager.can_get_roster?
        Logger.error "Attempted to get roster without permission"
        return nil
      end

      iq = Stanza::IQ.new
      iq.type = "get"
      iq.to = user_jid
      iq.id = generate_id

      roster = Stanza::Roster.new
      iq.payload = roster

      send(iq)
      iq.id
    end

    # Set a roster item (requires roster set permission)
    # Returns the IQ ID for tracking the response
    def set_roster_item(user_jid : String, item_jid : String, name : String = "", groups : Array(String) = [] of String) : String?
      unless @privilege_manager.can_set_roster?
        Logger.error "Attempted to set roster without permission"
        return nil
      end

      iq = Stanza::IQ.new
      iq.type = "set"
      iq.to = user_jid
      iq.id = generate_id

      roster = Stanza::Roster.new
      item = Stanza::RosterItem.new
      item.jid = item_jid
      item.name = name unless name.blank?
      groups.each { |grp| item.group << grp }
      roster.items << item

      iq.payload = roster

      send(iq)
      iq.id
    end

    # Send a message on behalf of a user (requires message outgoing permission)
    def send_privileged_message(from_jid : String, to_jid : String, body : String)
      unless @privilege_manager.can_send_messages?
        Logger.error "Attempted to send message without permission"
        return
      end

      # Create the actual message
      msg = Stanza::Message.new
      msg.from = from_jid
      msg.to = to_jid
      msg.body = body

      # Wrap in forwarded
      forwarded = Stanza::Forwarded.new
      forwarded.stanza = msg

      # Create privilege wrapper
      privilege = Stanza::Privilege.new
      privilege.forwarded = forwarded

      # Create wrapper message
      wrapper = Stanza::Message.new
      wrapper.to = extract_domain(from_jid) # Send to server
      wrapper.id = generate_id
      wrapper.extensions << privilege

      send(wrapper)
    end

    # Handle roster pushes (if permission granted)
    def handle_roster_push(iq : Stanza::IQ)
      return unless @privilege_manager.receives_roster_pushes?
      return unless iq.type == "set"

      # Extract roster item from IQ
      Logger.debug "Received roster push from: #{iq.from}"

      # Process roster update
      # In real implementation, would parse roster item and notify application
    end

    # Setup privilege handlers
    def setup_privilege_handlers
      # Handle privilege advertisements (in messages)
      @router.route(->(_s : Sender, p : Stanza::Packet) {
        if msg = p.as?(Stanza::Message)
          # Check for privilege namespace
          if msg.extensions.any? { |ext| ext.responds_to?(:xml_name) && ext.xml_name.to_s.includes?("privilege") }
            handle_privilege_advertisement(msg)
          end
        end
      }).message

      # Handle roster pushes (if we have permission)
      @router.route(->(_s : Sender, p : Stanza::Packet) {
        if iq = p.as?(Stanza::IQ)
          if @privilege_manager.receives_roster_pushes?
            handle_roster_push(iq)
          end
        end
      }).iq_namespaces(["jabber:iq:roster"])
    end

    # Helper to extract domain from JID
    private def extract_domain(jid : String) : String
      parts = jid.split('@')
      return jid if parts.size == 1
      parts[1].split('/')[0]
    end

    # Helper to generate unique IDs
    private def generate_id : String
      "priv_#{Time.utc.to_unix_ms}"
    end
  end
end
