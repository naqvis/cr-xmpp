#!/bin/bash
# Generate self-signed certificates for testing

CERT_DIR="./docker/prosody/certs"
mkdir -p "$CERT_DIR"

# Generate private key and self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/localhost.key" -out "$CERT_DIR/localhost.crt" \
    -days 365 -nodes -subj "/CN=localhost/O=XMPP Test Server/C=US"

# Set proper permissions
chmod 644 "$CERT_DIR/localhost.crt"
chmod 600 "$CERT_DIR/localhost.key"

echo "✓ Certificates generated in $CERT_DIR"
echo "  - localhost.crt (certificate)"
echo "  - localhost.key (private key)"
