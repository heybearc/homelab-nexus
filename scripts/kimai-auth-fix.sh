#!/bin/bash
#
# Kimai SAML Authentication Diagnostic and Fix Script
# Checks Kimai configuration and attempts to fix common SAML issues
#

set -e

KIMAI_HOST="10.92.3.76"
KIMAI_USER="root"

echo "=== Kimai SAML Authentication Diagnostic ==="
echo ""

# Check if we can SSH to Kimai
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${KIMAI_USER}@${KIMAI_HOST} "echo 'SSH OK'" 2>/dev/null; then
    echo "ERROR: Cannot SSH to Kimai container at ${KIMAI_HOST}"
    echo "Please ensure SSH keys are configured"
    exit 1
fi

echo "✓ SSH connection to Kimai OK"
echo ""

# Get current Kimai configuration
echo "=== Current Kimai SAML Configuration ==="
ssh ${KIMAI_USER}@${KIMAI_HOST} "grep -E 'APP_URL|SAML|TRUSTED' /var/www/kimai/.env 2>/dev/null || echo 'No .env file found'"
echo ""

# Check SAML YAML configuration
echo "=== SAML YAML Configuration ==="
ssh ${KIMAI_USER}@${KIMAI_HOST} "cat /var/www/kimai/config/packages/kimai_saml.yaml 2>/dev/null | head -50"
echo ""

# Check Kimai logs for SAML errors
echo "=== Recent SAML Errors in Kimai Logs ==="
ssh ${KIMAI_USER}@${KIMAI_HOST} "tail -100 /var/www/kimai/var/log/prod.log 2>/dev/null | grep -i saml || echo 'No SAML errors found'"
echo ""

# Check if APP_URL is set correctly
echo "=== Checking APP_URL Configuration ==="
APP_URL=$(ssh ${KIMAI_USER}@${KIMAI_HOST} "grep '^APP_URL=' /var/www/kimai/.env 2>/dev/null | cut -d= -f2")
if [ -z "$APP_URL" ]; then
    echo "⚠ APP_URL is not set in .env file"
    echo "This may cause RelayState issues in SAML flow"
    echo ""
    echo "Recommended fix:"
    echo "  Add to /var/www/kimai/.env:"
    echo "  APP_URL=https://time.cloudigan.net"
elif [ "$APP_URL" != "https://time.cloudigan.net" ]; then
    echo "⚠ APP_URL is set to: $APP_URL"
    echo "Should be: https://time.cloudigan.net"
else
    echo "✓ APP_URL is correctly set to: $APP_URL"
fi
echo ""

# Test SAML metadata endpoint
echo "=== Testing Kimai SAML Metadata Endpoint ==="
METADATA=$(curl -s http://${KIMAI_HOST}/auth/saml/metadata 2>&1 | head -20)
if echo "$METADATA" | grep -q "EntityDescriptor"; then
    echo "✓ SAML metadata endpoint is accessible"
    echo "$METADATA" | grep -E "entityID|AssertionConsumerService" | head -5
else
    echo "⚠ SAML metadata endpoint returned unexpected response"
    echo "$METADATA"
fi
echo ""

# Check Nginx configuration
echo "=== Nginx Configuration for SAML ==="
ssh ${KIMAI_USER}@${KIMAI_HOST} "nginx -T 2>/dev/null | grep -A 10 'location.*saml' || echo 'No specific SAML location blocks found'"
echo ""

echo "=== Diagnostic Complete ==="
echo ""
echo "Common fixes:"
echo "1. Set APP_URL=https://time.cloudigan.net in /var/www/kimai/.env"
echo "2. Ensure TRUSTED_PROXIES includes NPM IP: 10.92.3.3"
echo "3. Verify Authentik SAML provider has correct ACS URL"
echo "4. Check Authentik property mappings include email, username, groups"
