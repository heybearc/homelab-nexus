#!/bin/bash
#
# Fix Kimai SAML Attribute Mapping
# Updates Kimai configuration to match Authentik's SAML attribute names
#

set -e

KIMAI_HOST="10.92.3.76"

echo "=== Fixing Kimai SAML Attribute Mapping ==="
echo ""

# The issue: Authentik sends attributes with these names:
# - http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress
# - http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name
# - http://schemas.xmlsoap.org/claims/Group
#
# But Kimai expects simple names like "email", "username"

echo "Step 1: Updating Kimai SAML configuration to use correct attribute names..."

ssh root@${KIMAI_HOST} bash <<'ENDSSH'
cd /var/www/kimai

# Backup current configuration
cp config/packages/kimai_saml.yaml config/packages/kimai_saml.yaml.backup

# Update the SAML attribute mappings
cat > config/packages/kimai_saml.yaml <<'EOF'
kimai:
    saml:
        provider: authentik
        activate: true
        title: Login with Authentik
        mapping:
            - { saml: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress', kimai: email }
            - { saml: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name', kimai: alias }
        roles:
            resetOnLogin: false
            attribute: 'http://schemas.xmlsoap.org/claims/Group'
            mapping:
                - { saml: 'authentik Admins', kimai: ROLE_ADMIN }
                - { saml: 'Authentik Users', kimai: ROLE_USER }
        connection:
            idp:
                entityId: "https://auth.cloudigan.net/"
                singleSignOnService:
                    url: "https://auth.cloudigan.net/application/saml/kimai/sso/binding/redirect/"
                    binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                singleLogoutService:
                    url: "https://auth.cloudigan.net/application/saml/kimai/slo/binding/redirect/"
                    binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                x509cert: "MIIFVDCCAzygAwIBAgIRAIreXTLvG0YkmtgqX1jCr5YwDQYJKoZIhvcNAQELBQAwHjEcMBoGA1UEAwwTYXV0aGVudGlrIDIwMjQuMTIuMTAeFw0yNjAzMjIyMDMzNTVaFw0yNzAzMjMyMDMzNTVaMFYxKjAoBgNVBAMMIWF1dGhlbnRpayBTZWxmLXNpZ25lZCBDZXJ0aWZpY2F0ZTESMBAGA1UECgwJYXV0aGVudGlrMRQwEgYDVQQLDAtTZWxmLXNpZ25lZDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOh2HohLldspDasr+6Y2nJCX1liQWSHG9if1HPATqqUZE/dRSmfclCPp6ade0WxNwS/vZ68YHVmyy4Vesu6vs9TpKjcq67dbxLecQ9LkQHZqaRX2xbs2YuQ4++jSDIH/Tpiu5XejRpBYvKc1MZsS9GJETHm6zTmvUlIROYWNTFLAlnY8/PmshmyaM9GPcXcfCkfA2RMmWHQWvk5Qt+zKkWsoBnvAny0POcdaX6Ry7YQBWZ+yT6wdHCJpIlbEA3WhgOVovi6W28wAfMx00Adaw5JHq3IuMJxBi1o8Icgj+w5OmR1ID37JlRwQdnJGlT2yBc/awfSYLuxT8xCv3H4nvg0dkA8iRJVvkOW0VG3L1WCui84unykoPB/uZCGGLp/kLxaDe+9vGsFeMmWwMiwvDtKDwmXg4Dq6jTOMn/i5g/cGmyjUTVnxxHJU9YL1Ji7wedNZJUrSd76mrnBqcD4WwUByfkMgbWswmu9WHGCwRUhU0Uvcwn8L+ZDROiKEKhyuokmyQrSshD96LWGRvV3vasKPXdsRRei3wdcIYqIZ2ilaF74J/ReZL6rJSdiZMSz6LLdXUSRpEdkVnPHm3XDPsCpOD0XYeL/JvscN0in2t2bgYdkcDBEq3kVUB9pzA2FmNCuPeV0K4W01GalqIS87D7bdhrQJZKAf0rtHvYNpwbMdAgMBAAGjVTBTMFEGA1UdEQEB/wRHMEWCQ3RNeE1Qa2dEeXAydERha0QzeElYdU5RSGlHVFBSUTFGVFAxbldjVXUuc2VsZi1zaWduZWQuZ29hdXRoZW50aWsuaW8wDQYJKoZIhvcNAQELBQADggIBABISM3kiHjFV5FfwTp+/evSjUlo80+7q8P/lL9B+/Wcxue+6bbt/YR6jPro6VG8ZnklsbLKib3MlGfdlOjLKBAdg3zAfDLWHXSc6BMXZtzivMmmb6BZX1mqHbWYZrlcV9Ue1QtrizFguIZZeFTO63bVqgvfS0413s8SnBfLk5AGf1mW2Uf16lG9z7/GT15CmWwsLjjNUZhNyoX77k8OoBrHvlj7JWGO/bV8tvtYEY1QGDV6VxJt/aY8UItvh8uhI1e6tjaSsLMkej03xqrNQRbaUYYLuIAbedYjcipDcbuipc60LkFoqOG1A0v1Zd9CCvqOJz6WTOMOw2VJ0QU7lGx9deboDfyj8l0isbYG/eSefZorQNUBNc8BmNzYWP+S4jKPbSgEqw7nJAgBVw58Mr/QJs1752qz81CwQYzf8sBSg4590d0xbuE37Qe404As0HACAQnnvbe7z/xHhApxU+0K+tpyzDu9xot36mvAbOd9tQcfKalQAOfZkwANE4MGRldBL4pwAMXAkkHxduIol+k8hFPMEYdU8WJnbLF9/Lt2/crJyVO9svK6fs/6UYuuYCGioPm18HKdAWKLIoJQC2kmeRFueSwfha9RJtVBU/sWAg7OyJA7brbPBUA08fB4HDYONWLU6m8HydNlSg0ZP37Fig3d36KAc7smo2exellxR"
            sp:
                entityId: "https://time.cloudigan.net/"
                assertionConsumerService:
                    url: "https://time.cloudigan.net/auth/saml/acs"
                    binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                singleLogoutService:
                    url: "https://time.cloudigan.net/auth/saml/logout"
                    binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
            baseurl: "https://time.cloudigan.net/auth/saml/"
            strict: false
            debug: true
            security:
                nameIdEncrypted: false
                authnRequestsSigned: false
                logoutRequestSigned: false
                logoutResponseSigned: false
                wantMessagesSigned: false
                wantAssertionsSigned: false
                wantNameIdEncrypted: false
                requestedAuthnContext: true
                signMetadata: false
                wantXMLValidation: true
                signatureAlgorithm: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
                digestAlgorithm: "http://www.w3.org/2001/04/xmlenc#sha256"
            contactPerson:
                technical:
                    givenName: "Kimai Admin"
                    emailAddress: "admin@cloudigan.com"
            organization:
                en:
                    name: "Cloudigan"
                    displayname: "Cloudigan"
                    url: "https://time.cloudigan.net"
EOF

echo "✓ Updated kimai_saml.yaml with correct attribute mappings"

# Also update .env to use the full attribute names
if ! grep -q "^SAML_MAPPING_UID=" .env; then
    echo "SAML_MAPPING_UID=http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" >> .env
else
    sed -i 's|^SAML_MAPPING_UID=.*|SAML_MAPPING_UID=http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress|' .env
fi

if ! grep -q "^SAML_MAPPING_EMAIL=" .env; then
    echo "SAML_MAPPING_EMAIL=http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" >> .env
else
    sed -i 's|^SAML_MAPPING_EMAIL=.*|SAML_MAPPING_EMAIL=http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress|' .env
fi

# Add APP_URL if missing
if ! grep -q "^APP_URL=" .env; then
    echo "APP_URL=https://time.cloudigan.net" >> .env
    echo "✓ Added APP_URL to .env"
fi

echo "✓ Updated .env with correct SAML mappings"

# Clear Symfony cache
rm -rf var/cache/*
echo "✓ Cleared Symfony cache"

# Restart PHP-FPM
systemctl restart php8.3-fpm
echo "✓ Restarted PHP-FPM"

ENDSSH

echo ""
echo "=== Fix Applied Successfully ==="
echo ""
echo "Changes made:"
echo "1. Updated SAML attribute mappings to use full URN format"
echo "2. Added APP_URL=https://time.cloudigan.net to .env"
echo "3. Cleared Symfony cache"
echo "4. Restarted PHP-FPM"
echo ""
echo "Test authentication:"
echo "  https://time.cloudigan.net"
echo ""
echo "If still having issues, check Authentik property mappings send these attributes:"
echo "  - http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
echo "  - http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
echo "  - http://schemas.xmlsoap.org/claims/Group"
