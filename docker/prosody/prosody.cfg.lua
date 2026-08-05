admins = {}

plugin_paths = { "/usr/local/lib/prosody/site-modules" }

modules_enabled = {
    "bosh";
    "cloud_notify";
    "csi";
    "disco";
    "ping";
    "pubsub";
    "pep";
    "sasl2";
    "sasl2_bind2";
    "saslauth";
    "smacks";
    "tls";
    "websocket";
}

allow_registration = false
c2s_require_encryption = true
authentication = "internal_hashed"
storage = "internal"

interfaces = { "*" }
component_interfaces = { "*" }
c2s_ports = { 5222 }
c2s_direct_tls_ports = { 5223 }
component_ports = { 5347 }

http_ports = { 5280 }
http_interfaces = { "*" }
cross_domain_websocket = true
consider_websocket_secure = true
consider_bosh_secure = true

log = {
    info = "*console";
    debug = "*console";
}

ssl = {
    key = "/etc/prosody/certs/localhost.key";
    certificate = "/etc/prosody/certs/localhost.crt";
}

sasl_mechanisms = {
    "SCRAM-SHA-512-PLUS";
    "SCRAM-SHA-256-PLUS";
    "SCRAM-SHA-1-PLUS";
    "SCRAM-SHA-512";
    "SCRAM-SHA-256";
    "SCRAM-SHA-1";
    "PLAIN";
}

VirtualHost "localhost"
    enabled = true

Component "component.localhost"
    component_secret = "component-secret"
