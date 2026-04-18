#!/bin/bash
#
# Configure Kimai for Direct Entra ID SAML Authentication
#

set -e

KIMAI_HOST="10.92.3.76"
TENANT_ID="8e44be3f-91ca-4ea4-9148-56ecc910f556"

echo "=== Configuring Kimai for Entra ID SAML ==="
echo ""

# Read the certificate and format it for YAML (single line, no headers)
CERT_CONTENT=$(cat "Cloudigan Kimai.cer" | grep -v "BEGIN CERTIFICATE" | grep -v "END CERTIFICATE" | tr -d '\n')

echo "✓ Certificate loaded"

ssh root@${KIMAI_HOST} bash <<ENDSSH
cd /var/www/kimai

# Backup existing config
cp config/packages/kimai_saml.yaml config/packages/kimai_saml.yaml.authentik-backup 2>/dev/null || true

# Create new Entra ID SAML configuration
cat > config/packages/kimai_saml.yaml <<'EOF'
kimai:
    saml:
        activate: true
        title: Login with Microsoft
        provider: azure
        mapping:
            - { saml: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress', kimai: email }
            - { saml: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name', kimai: alias }
        roles:
            resetOnLogin: true
            attribute: 'http://schemas.microsoft.com/ws/2008/06/identity/claims/groups'
            mapping:
                - { saml: 'Kimai Admins', kimai: ROLE_ADMIN }
                - { saml: 'Kimai Users', kimai: ROLE_USER }
        connection:
            idp:
                entityId: 'https://sts.windows.net/${TENANT_ID}/'
                singleSignOnService:
                    url: 'https://login.microsoftonline.com/${TENANT_ID}/saml2'
                    binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'
                singleLogoutService:
                    url: 'https://login.microsoftonline.com/${TENANT_ID}/saml2'
                    binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'
                x509cert: '${CERT_CONTENT}'
            sp:
                entityId: 'https://time.cloudigan.net/'
                assertionConsumerService:
                    url: 'https://time.cloudigan.net/auth/saml/acs'
                    binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST'
                singleLogoutService:
                    url: 'https://time.cloudigan.net/auth/saml/logout'
                    binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'
            baseurl: 'https://time.cloudigan.net/auth/saml/'
            strict: true
            debug: false
            security:
                nameIdEncrypted: false
                authnRequestsSigned: false
                logoutRequestSigned: false
                logoutResponseSigned: false
                wantMessagesSigned: false
                wantAssertionsSigned: true
                wantNameIdEncrypted: false
                requestedAuthnContext: true
                signMetadata: false
                wantXMLValidation: true
                signatureAlgorithm: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
                digestAlgorithm: 'http://www.w3.org/2001/04/xmlenc#sha256'
            contactPerson:
                technical:
                    givenName: 'Kimai Admin'
                    emailAddress: 'admin@cloudigan.com'
            organization:
                en:
                    name: 'Cloudigan'
                    displayname: 'Cloudigan'
                    url: 'https://time.cloudigan.net'
EOF

echo "✓ Created Entra ID SAML configuration"

# Update .env
sed -i 's/^SAML_ACTIVATE=.*/SAML_ACTIVATE=true/' .env
sed -i 's/^SAML_TITLE=.*/SAML_TITLE="Login with Microsoft"/' .env
sed -i 's/^SAML_PROVIDER=.*/SAML_PROVIDER=azure/' .env

# Ensure APP_URL is set
if ! grep -q "^APP_URL=" .env; then
    echo "APP_URL=https://time.cloudigan.net" >> .env
fi

echo "✓ Updated .env"

# Clear cache
rm -rf var/cache/*
echo "✓ Cleared cache"

# Restart services
systemctl restart php8.3-fpm nginx
echo "✓ Restarted PHP-FPM and Nginx"

ENDSSH

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Kimai is now configured for Entra ID SAML authentication"
echo ""
echo "Test login at: https://time.cloudigan.net"
echo ""
echo "Configuration details:"
echo "  Provider: Microsoft Entra ID (Azure)"
echo "  Entity ID: https://sts.windows.net/${TENANT_ID}/"
echo "  SSO URL: https://login.microsoftonline.com/${TENANT_ID}/saml2"
echo "  ACS URL: https://time.cloudigan.net/auth/saml/acs"
echo ""
echo "Next steps:"
echo "1. Ensure users are assigned to the 'Cloudigan Kimai' app in Entra ID"
echo "2. Test login with a user account"
echo "3. If needed, create 'Kimai Admins' and 'Kimai Users' groups in Entra ID"
