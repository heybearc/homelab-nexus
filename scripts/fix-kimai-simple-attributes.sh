#!/bin/bash
#
# Fix Kimai to use simple SAML attribute names (what Authentik actually sends)
#

set -e

echo "=== Reverting to Simple SAML Attribute Names ==="
echo ""

# Authentik's default SAML mappings send simple names:
# - email (not the full URN)
# - name (not the full URN)  
# - groups (not the full URN)

ssh root@10.92.3.76 bash <<'ENDSSH'
cd /var/www/kimai

# Update to use simple attribute names
cat > config/packages/kimai_saml.yaml <<'EOF'
kimai:
    saml:
        provider: authentik
        activate: true
        title: Login with Authentik
        mapping:
            - { saml: email, kimai: email }
            - { saml: name, kimai: alias }
        roles:
            resetOnLogin: false
            attribute: groups
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

echo "✓ Updated to simple attribute names (email, name, groups)"

# Update .env as well
sed -i 's|^SAML_MAPPING_UID=.*|SAML_MAPPING_UID=email|' .env
sed -i 's|^SAML_MAPPING_EMAIL=.*|SAML_MAPPING_EMAIL=email|' .env

echo "✓ Updated .env"

# Clear cache
rm -rf var/cache/*
echo "✓ Cleared cache"

# Restart PHP-FPM
systemctl restart php8.3-fpm
echo "✓ Restarted PHP-FPM"

ENDSSH

echo ""
echo "=== Fix Applied ==="
echo ""
echo "Now using simple SAML attribute names:"
echo "  - email → email"
echo "  - name → alias"
echo "  - groups → groups"
echo ""
echo "Test again at: https://time.cloudigan.net"
