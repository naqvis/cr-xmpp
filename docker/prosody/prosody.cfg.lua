-- Prosody XMPP Server Configuration for cr-xmpp Testing
-- Optimized for testing channel binding and SCRAM-PLUS authentication

-- Server identification
admins = { "admin@localhost" }

-- Modules to enable
modules_enabled = {
    -- Core features
    "roster";           -- Allow users to have a roster
    "saslauth";         -- Authentication for clients
    "tls";              -- Add support for secure TLS on c2s/s2s connections
    "dialback";         -- s2s dialback support
    "disco";            -- Service discovery
    
    -- Nice to have
    "carbons";          -- Keep multiple clients in sync
    "pep";              -- Enables users to publish their avatar, mood, activity, playing music and more
    "private";          -- Private XML storage (for room bookmarks, etc.)
    "blocklist";        -- Allow users to block communications with other users
    "vcard4";           -- User profiles (stored in PEP)
    "vcard_legacy";     -- Conversion between legacy vCard and PEP Avatar, vcard
    
    -- Admin interfaces
    "admin_adhoc";      -- Allows administration via an XMPP client that supports ad-hoc commands
    "admin_telnet";     -- Opens telnet console interface on localhost port 5582
    
    -- HTTP modules
    "bosh";             -- Enable BOSH clients, aka "Jabber over HTTP"
    "websocket";        -- XMPP over WebSockets
    "http_files";       -- Serve static files from a directory over HTTP
    
    -- Other specific functionality
    "ping";             -- Replies to XMPP pings with pongs
    "register";         -- Allow users to register on this server using a client and change passwords
    "time";             -- Let others know the time here on this server
    "uptime";           -- Report how long server has been running
    "version";          -- Replies to server version requests
    "mam";              -- Store messages in an archive and allow users to access it
    "csi_simple";       -- Simple Mobile optimizations
    
    -- Stream management (requires community module - optional)
    -- "smacks";           -- Stream Management and resumption (XEP-0198)
}

-- Disable modules not needed for testing
modules_disabled = {
    -- "offline"; -- Store offline messages
    -- "c2s"; -- Handle client connections
    -- "s2s"; -- Handle server-to-server connections
}

-- Allow registration of new accounts
allow_registration = true

-- Force clients to use encrypted connections
c2s_require_encryption = false  -- Set to false for easier testing, true for production

-- Force servers to use encrypted connections
s2s_require_encryption = false

-- Select the authentication backend
authentication = "internal_hashed"

-- Storage configuration
storage = "internal"

-- Logging configuration
log = {
    info = "*console";
    -- debug = "*console"; -- Uncomment for verbose logging
}

-- Network settings
interfaces = { "*" }
c2s_ports = { 5222 }
s2s_ports = { 5269 }

-- HTTP settings
http_ports = { 5280 }
http_interfaces = { "*" }
https_ports = { 5281 }
https_interfaces = { "*" }

-- SSL/TLS configuration
ssl = {
    key = "/etc/prosody/certs/localhost.key";
    certificate = "/etc/prosody/certs/localhost.crt";
}

-- SASL configuration - Enable SCRAM mechanisms with channel binding support
sasl_mechanisms = {
    "SCRAM-SHA-512-PLUS",
    "SCRAM-SHA-256-PLUS", 
    "SCRAM-SHA-1-PLUS",
    "SCRAM-SHA-512",
    "SCRAM-SHA-256",
    "SCRAM-SHA-1",
    "PLAIN"
}

-- Virtual hosts
VirtualHost "localhost"
    enabled = true

-- Components (for testing component protocol)
Component "conference.localhost" "muc"
    modules_enabled = {
        "muc_mam";
    }
    restrict_room_creation = false

-- Set up an external component (for testing XEP-0114)
-- Component "gateway.localhost"
--     component_secret = "secret"
