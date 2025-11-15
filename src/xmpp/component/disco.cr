require "../stanza"

module XMPP
  # XEP-0030: Service Discovery support for components
  # Allows components to automatically respond to disco#info and disco#items queries
  module ComponentDisco
    # DiscoIdentity represents a single identity for service discovery
    struct DiscoIdentity
      property category : String
      property type : String
      property name : String
      property xml_lang : String

      def initialize(@category, @type, @name = "", @xml_lang = "")
      end

      def to_identity : Stanza::Identity
        identity = Stanza::Identity.new
        identity.category = @category
        identity.type = @type
        identity.name = @name unless @name.blank?
        identity
      end
    end

    # DiscoInfo holds the service discovery information for a component
    class DiscoInfo
      property identities : Array(DiscoIdentity) = Array(DiscoIdentity).new
      property features : Array(String) = Array(String).new
      property nodes : Hash(String, DiscoNodeInfo) = Hash(String, DiscoNodeInfo).new

      def initialize
        # Every entity MUST support disco#info
        @features << "http://jabber.org/protocol/disco#info"
        @features << "http://jabber.org/protocol/disco#items"
      end

      # Add an identity to the component
      def add_identity(category : String, type : String, name : String = "", xml_lang : String = "")
        @identities << DiscoIdentity.new(category, type, name, xml_lang)
      end

      # Add a feature to the component
      def add_feature(feature : String)
        @features << feature unless @features.includes?(feature)
      end

      # Add multiple features at once
      def add_features(features : Array(String))
        features.each { |feat| add_feature(feat) }
      end

      # Add a node with its own disco info
      def add_node(node : String, info : DiscoNodeInfo)
        @nodes[node] = info
      end

      # Get disco info for a specific node
      def get_node(node : String) : DiscoNodeInfo?
        @nodes[node]?
      end

      # Build a disco#info response
      def build_response(node : String = "") : Stanza::DiscoInfo
        info = Stanza::DiscoInfo.new
        info.node = node unless node.blank?

        if node.blank?
          # Root node - return component's identities and features
          @identities.each do |identity|
            info.identity << identity.to_identity
          end
          @features.each do |feature|
            f = Stanza::Feature.new
            f.var = feature
            info.features << f
          end
        else
          # Specific node - check if we have info for it
          if node_info = @nodes[node]?
            node_info.identities.each do |identity|
              info.identity << identity.to_identity
            end
            node_info.features.each do |feature|
              f = Stanza::Feature.new
              f.var = feature
              info.features << f
            end
          end
        end

        info
      end
    end

    # DiscoNodeInfo holds disco information for a specific node
    class DiscoNodeInfo
      property identities : Array(DiscoIdentity) = Array(DiscoIdentity).new
      property features : Array(String) = Array(String).new

      def initialize
        # Nodes should also support disco
        @features << "http://jabber.org/protocol/disco#info"
      end

      def add_identity(category : String, type : String, name : String = "")
        @identities << DiscoIdentity.new(category, type, name)
      end

      def add_feature(feature : String)
        @features << feature unless @features.includes?(feature)
      end
    end

    # DiscoItems holds the items associated with the component
    class DiscoItems
      property items : Array(Stanza::DiscoItem) = Array(Stanza::DiscoItem).new
      property node_items : Hash(String, Array(Stanza::DiscoItem)) = Hash(String, Array(Stanza::DiscoItem)).new

      # Add an item to the root
      def add_item(jid : String, node : String = "", name : String = "")
        @items << Stanza::DiscoItem.new(jid, node, name)
      end

      # Add an item to a specific node
      def add_node_item(parent_node : String, jid : String, node : String = "", name : String = "")
        @node_items[parent_node] ||= Array(Stanza::DiscoItem).new
        @node_items[parent_node] << Stanza::DiscoItem.new(jid, node, name)
      end

      # Build a disco#items response
      def build_response(node : String = "") : Stanza::DiscoItems
        items_response = Stanza::DiscoItems.new
        items_response.node = node unless node.blank?

        if node.blank?
          # Root node - return all items
          items_response.items = @items.dup
        else
          # Specific node - return items for that node
          if node_items = @node_items[node]?
            items_response.items = node_items.dup
          end
        end

        items_response
      end
    end

    # Handle disco#info request
    def handle_disco_info(iq : Stanza::IQ, disco_info : DiscoInfo)
      response = Stanza::IQ.new
      response.type = "result"
      response.id = iq.id
      response.to = iq.from
      response.from = iq.to

      # Extract node if present
      node = ""
      if payload = iq.payload.as?(Stanza::DiscoInfo)
        node = payload.node
      end

      # Build and set response
      response.payload = disco_info.build_response(node)
      send response
    end

    # Handle disco#items request
    def handle_disco_items(iq : Stanza::IQ, disco_items : DiscoItems)
      response = Stanza::IQ.new
      response.type = "result"
      response.id = iq.id
      response.to = iq.from
      response.from = iq.to

      # Extract node if present
      node = ""
      if payload = iq.payload.as?(Stanza::DiscoItems)
        node = payload.node
      end

      # Build and set response
      response.payload = disco_items.build_response(node)
      send response
    end

    # Setup automatic disco handlers
    def setup_disco_handlers(disco_info : DiscoInfo, disco_items : DiscoItems)
      # Handle disco#info queries
      @router.route(->(_s : Sender, p : Stanza::Packet) {
        if iq = p.as?(Stanza::IQ)
          if iq.type == "get" && iq.payload.is_a?(Stanza::DiscoInfo)
            handle_disco_info(iq, disco_info)
          end
        end
      }).iq_namespaces(["http://jabber.org/protocol/disco#info"])

      # Handle disco#items queries
      @router.route(->(_s : Sender, p : Stanza::Packet) {
        if iq = p.as?(Stanza::IQ)
          if iq.type == "get" && iq.payload.is_a?(Stanza::DiscoItems)
            handle_disco_items(iq, disco_items)
          end
        end
      }).iq_namespaces(["http://jabber.org/protocol/disco#items"])
    end
  end
end
