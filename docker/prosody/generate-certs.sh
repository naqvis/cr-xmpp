#!/usr/bin/env bash
set -euo pipefail

# Generate an isolated test CA and a hostname-valid localhost server
# certificate. The CA is passed explicitly to the client integration tests.

CERT_DIR="./docker/prosody/certs"
mkdir -p "$CERT_DIR"

openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
    -keyout "$CERT_DIR/ca.key" \
    -out "$CERT_DIR/ca.crt" \
    -days 7 \
    -subj "/CN=cr-xmpp integration CA/O=cr-xmpp" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"

openssl req -new -newkey rsa:3072 -sha256 -nodes \
    -keyout "$CERT_DIR/localhost.key" \
    -out "$CERT_DIR/localhost.csr" \
    -subj "/CN=localhost/O=cr-xmpp"

openssl x509 -req -sha256 \
    -in "$CERT_DIR/localhost.csr" \
    -CA "$CERT_DIR/ca.crt" \
    -CAkey "$CERT_DIR/ca.key" \
    -CAserial "$CERT_DIR/ca.srl" \
    -CAcreateserial \
    -out "$CERT_DIR/localhost.crt" \
    -days 7 \
    -extfile "./docker/prosody/localhost.ext"

rm -f "$CERT_DIR/localhost.csr" "$CERT_DIR/ca.srl"
chmod 644 "$CERT_DIR/ca.crt" "$CERT_DIR/localhost.crt" "$CERT_DIR/ca.key" "$CERT_DIR/localhost.key"

echo "Generated trusted integration certificates in $CERT_DIR"
