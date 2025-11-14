#!/bin/bash
set -e

# Fix permissions for prosody user
chown -R prosody:prosody /var/lib/prosody /var/log/prosody 2>/dev/null || true

# Start Prosody as prosody user in the background
su prosody -s /bin/bash -c "prosody" &
PROSODY_PID=$!

# Wait for Prosody to be ready
echo "Waiting for Prosody to start..."
sleep 5

# Create test users if they don't exist
echo "Creating test users..."
prosodyctl register admin localhost admin123 2>/dev/null && echo "✓ Created admin@localhost" || echo "  admin@localhost already exists"
prosodyctl register test localhost test 2>/dev/null && echo "✓ Created test@localhost" || echo "  test@localhost already exists"
prosodyctl register user2 localhost password2 2>/dev/null && echo "✓ Created user2@localhost" || echo "  user2@localhost already exists"

echo ""
echo "✓ Prosody XMPP server is ready!"
echo ""
echo "Available test accounts:"
echo "  - admin@localhost (password: admin123)"
echo "  - test@localhost (password: test)"
echo "  - user2@localhost (password: password2)"
echo ""

# Bring Prosody to foreground
wait $PROSODY_PID
