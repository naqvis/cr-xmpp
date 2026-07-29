# Local Prosody environment

The repository has one canonical [`docker-compose.yml`](../docker-compose.yml)
for both manual development and automated interoperability testing. It uses a
digest-pinned Prosody 13 image, certificate-required client connections, a
health check, and a persistent project-scoped data volume.

This setup is for local development and testing, not production deployment.

## Automated integration gate

From the repository root:

```bash
./scripts/ci integration
```

The script:

1. generates a temporary localhost CA and server certificate;
2. starts Compose under the isolated `cr-xmpp-integration` project on client
   port 55222 and component port 55535;
3. creates `test@localhost`;
4. runs live TLS, SASL, XEP-0198 cut/resume, component authentication,
   lifecycle, and concurrency specs; and
5. removes its container and volume.

It does not reuse or delete the default manual-development Compose project.

## Manual server

Generate certificates and start Prosody:

```bash
./docker/prosody/generate-certs.sh
docker compose up --detach --wait
docker compose exec prosody prosodyctl register test localhost test
```

The default client and component ports are 5222 and 5347. Override them when
needed:

```bash
XMPP_PORT=55222 XMPP_COMPONENT_PORT=55535 docker compose up --detach --wait
```

Connect a client using:

- host: `localhost`
- port: `5222` (or the chosen `XMPP_PORT`)
- JID: `test@localhost`
- password: `test`
- CA bundle: `docker/prosody/certs/ca.crt`

## Commands

```bash
# Status and logs
docker compose ps
docker compose logs --follow prosody

# User management
docker compose exec prosody prosodyctl list localhost
docker compose exec prosody prosodyctl passwd test@localhost
docker compose exec prosody prosodyctl deluser test@localhost

# Restart
docker compose restart prosody

# Stop while retaining data
docker compose down

# Stop and remove the project volume
docker compose down --volumes
```

## Troubleshooting

### Connection refused

Check `docker compose ps`, inspect the Prosody logs, and verify that the chosen
host port is available.

### Certificate verification failed

Regenerate the certificates and configure:

```crystal
tls_ca_certificates: "docker/prosody/certs/ca.crt"
```

The generated certificate is valid for `localhost`; connecting with a
different hostname will correctly fail hostname verification.

### Authentication failed

List the accounts with `prosodyctl` and recreate the test user if necessary.
Registration from XMPP clients is disabled by the server configuration.

### Inspect TLS

```bash
openssl s_client \
  -connect localhost:5222 \
  -starttls xmpp \
  -CAfile docker/prosody/certs/ca.crt
```
