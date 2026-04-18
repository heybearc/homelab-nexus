#!/bin/bash
#
# Fix Kimai CSRF token issue with SAML authentication
#

set -e

KIMAI_HOST="10.92.3.76"

echo "=== Fixing Kimai SAML CSRF Token Issue ==="
echo ""

ssh root@${KIMAI_HOST} bash <<'ENDSSH'
cd /var/www/kimai

# Backup current framework config
cp config/packages/framework.yaml config/packages/framework.yaml.backup

# Update session configuration to work better with SAML
# Change cookie_samesite from 'lax' to 'none' and ensure cookie_secure is true
sed -i 's/cookie_samesite: lax/cookie_samesite: none/' config/packages/framework.yaml
sed -i 's/cookie_secure: auto/cookie_secure: true/' config/packages/framework.yaml

echo "✓ Updated session cookie settings for SAML compatibility"

# Also ensure APP_URL is properly set in .env
if ! grep -q "^APP_URL=" .env; then
    echo "APP_URL=https://time.cloudigan.net" >> .env
else
    sed -i 's|^APP_URL=.*|APP_URL=https://time.cloudigan.net|' .env
fi

# Set trusted proxies (needed for proper HTTPS detection behind reverse proxy)
if ! grep -q "^TRUSTED_PROXIES=" .env; then
    echo "TRUSTED_PROXIES=10.92.3.0/24,127.0.0.1" >> .env
else
    sed -i 's|^TRUSTED_PROXIES=.*|TRUSTED_PROXIES=10.92.3.0/24,127.0.0.1|' .env
fi

# Set trusted hosts
if ! grep -q "^TRUSTED_HOSTS=" .env; then
    echo "TRUSTED_HOSTS=^time\\.cloudigan\\.net$" >> .env
else
    sed -i 's|^TRUSTED_HOSTS=.*|TRUSTED_HOSTS=^time\\.cloudigan\\.net$|' .env
fi

echo "✓ Updated .env with proxy and host settings"

# Clear all caches
rm -rf var/cache/*
echo "✓ Cleared cache"

# Clear sessions to force fresh start
rm -rf var/sessions/*
echo "✓ Cleared sessions"

# Restart PHP-FPM and Nginx
systemctl restart php8.3-fpm nginx
echo "✓ Restarted services"

ENDSSH

echo ""
echo "=== Fix Applied ==="
echo ""
echo "Changes made:"
echo "  1. Set cookie_samesite to 'none' (required for cross-domain SAML)"
echo "  2. Set cookie_secure to 'true' (required when using samesite=none)"
echo "  3. Configured trusted proxies for proper HTTPS detection"
echo "  4. Configured trusted hosts"
echo "  5. Cleared cache and sessions"
echo ""
echo "Test SAML login at: https://time.cloudigan.net/auth/saml/login"
echo ""
