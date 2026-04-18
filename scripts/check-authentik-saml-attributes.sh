#!/bin/bash
#
# Check what SAML attributes Authentik is actually sending
#

set -e

echo "=== Checking Authentik SAML Attribute Configuration ==="
echo ""

# Enable verbose SAML debugging in Kimai to see what attributes are received
echo "Step 1: Enabling SAML debug logging in Kimai..."
ssh root@10.92.3.76 bash <<'ENDSSH'
cd /var/www/kimai

# Enable SAML debug mode
sed -i 's/debug: false/debug: true/' config/packages/kimai_saml.yaml 2>/dev/null || true

# Clear logs to see fresh output
> var/log/prod.log

echo "✓ SAML debug enabled, logs cleared"
ENDSSH

echo ""
echo "Step 2: Test authentication and capture SAML response..."
echo ""
echo "Please try logging in at: https://time.cloudigan.net"
echo "Then press Enter to view the SAML debug logs..."
read -p "Press Enter after attempting login: "

echo ""
echo "=== SAML Debug Logs ==="
ssh root@10.92.3.76 "tail -100 /var/www/kimai/var/log/prod.log | grep -A 20 -B 5 -i 'saml\|attribute\|assertion'"

echo ""
echo "=== Checking received SAML attributes ==="
ssh root@10.92.3.76 "grep -i 'attribute' /var/www/kimai/var/log/prod.log | tail -20"
