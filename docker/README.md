# Docker Development Environment

This directory contains Docker Compose configuration for running an XMPP server for testing and development.

## Quick Start

1. **Generate SSL certificates** (required for TLS and channel binding):

   ```bash
   ./docker/prosody/generate-certs.sh
   ```

2. **Start the XMPP server** (test users are created automatically):

   ```bash
   docker-compose up -d
   ```

3. **Check server status**:

   ```bash
   docker-compose ps
   docker-compose logs -f prosody
   ```

   **Test accounts created automatically:**

   - `admin@localhost` (password: `admin123`)
   - `test@localhost` (password: `test`)
   - `user2@localhost` (password: `password2`)

4. **Run examples**:

   ```bash
   # Set environment variables
   export XMPP_HOST=localhost
   export XMPP_JID=test@localhost
   export XMPP_PASSWORD=test

   # Run the channel binding example
   crystal run examples/xmpp_channel_binding.cr

   # Or the echo bot
   crystal run examples/xmpp_echo.cr
   ```

## Server Configuration

### Prosody (Default)

- **C2S Port**: 5222 (Client-to-Server)
- **S2S Port**: 5269 (Server-to-Server)
- **HTTP Port**: 5280 (BOSH/WebSocket)
- **HTTPS Port**: 5281 (Secure BOSH/WebSocket)
- **Domain**: localhost
- **Admin User**: admin@localhost (password: admin123)

### Supported Features

- ✅ TLS/SSL encryption
- ✅ SCRAM-SHA-512-PLUS, SCRAM-SHA-256-PLUS, SCRAM-SHA-1-PLUS (with channel binding)
- ✅ SCRAM-SHA-512, SCRAM-SHA-256, SCRAM-SHA-1
- ✅ Stream Management (XEP-0198)
- ✅ Message Archive Management (XEP-0313)
- ✅ Multi-User Chat (XEP-0045)
- ✅ Service Discovery (XEP-0030)
- ✅ BOSH and WebSocket support

## Testing Channel Binding

The server is configured to support channel binding (XEP-0440) with SCRAM-PLUS mechanisms:

```crystal
require "cr-xmpp"

config = XMPP::Config.new(
  host: "localhost",
  jid: "test@localhost",
  password: "test",
  tls: true,  # Required for channel binding
  skip_cert_verify: true,  # For self-signed certs in testing
)

client = XMPP::Client.new(config)
# Will automatically use SCRAM-PLUS if available
```

## Useful Commands

### User Management

```bash
# List all users
docker-compose exec prosody prosodyctl list localhost

# Change password
docker-compose exec prosody prosodyctl passwd test@localhost

# Delete user
docker-compose exec prosody prosodyctl deluser test@localhost
```

### Server Management

```bash
# Restart server
docker-compose restart prosody

# View logs
docker-compose logs -f prosody

# Access Prosody console
docker-compose exec prosody prosodyctl shell

# Check server status
docker-compose exec prosody prosodyctl status
```

### Debugging

```bash
# Enable debug logging (edit prosody.cfg.lua and uncomment debug line)
# Then restart:
docker-compose restart prosody

# Check TLS certificate
openssl s_client -connect localhost:5222 -starttls xmpp

# Test XMPP connection
telnet localhost 5222
```

## Stopping the Server

```bash
# Stop but keep data
docker-compose stop

# Stop and remove containers (keeps volumes)
docker-compose down

# Stop and remove everything including data
docker-compose down -v
```

## Alternative: ejabberd

To use ejabberd instead of Prosody:

1. Edit `docker-compose.yml` and comment out the `prosody` service
2. Uncomment the `ejabberd` service
3. Create ejabberd configuration in `docker/ejabberd/ejabberd.yml`
4. Run `docker-compose up -d`

## Troubleshooting

### Connection Refused

- Ensure the server is running: `docker-compose ps`
- Check logs: `docker-compose logs prosody`
- Verify ports are not in use: `lsof -i :5222`

### Certificate Errors

- Regenerate certificates: `./docker/prosody/generate-certs.sh`
- Use `skip_cert_verify: true` in config for self-signed certs

### Authentication Failures

- Verify user exists: `docker-compose exec prosody prosodyctl list localhost`
- Check password: Try recreating the user
- Review logs: `docker-compose logs -f prosody`

### Channel Binding Not Working

- Ensure TLS is enabled in client config
- Verify server supports SCRAM-PLUS: Check server features in logs
- Confirm certificates are properly generated

## Production Notes

⚠️ **This setup is for development/testing only!**

For production:

- Use proper SSL certificates (Let's Encrypt)
- Set `c2s_require_encryption = true`
- Set `allow_registration = false`
- Use strong admin passwords
- Configure proper firewall rules
- Enable rate limiting
- Set up proper logging and monitoring
