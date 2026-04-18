#!/bin/bash
#
# Update Kimai local.yaml to use Entra ID instead of Authentik
#

set -e

KIMAI_HOST="10.92.3.76"
TENANT_ID="8e44be3f-91ca-4ea4-9148-56ecc910f556"

echo "=== Updating local.yaml for Entra ID SAML ==="
echo ""

# Create the config file locally first
cat > /tmp/kimai_local.yaml << 'LOCALEOF'
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
                entityId: 'https://sts.windows.net/8e44be3f-91ca-4ea4-9148-56ecc910f556/'
                singleSignOnService:
                    url: 'https://login.microsoftonline.com/8e44be3f-91ca-4ea4-9148-56ecc910f556/saml2'
                    binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'
                singleLogoutService:
                    url: 'https://login.microsoftonline.com/8e44be3f-91ca-4ea4-9148-56ecc910f556/saml2'
                    binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'
                x509cert: |
                    MIIC/TCCAeWgAwIBAgIILaami+xa9gMwDQYJKoZIhvcNAQELBQAwLTErMCkGA1UEAxMiYWNjb3VudHMuYWNjZXNzY29udHJvbC53aW5kb3dzLm5ldDAeFw0yNjAyMjEwNTAzMDZaFw0zMTAyMjEwNTAzMDZaMC0xKzApBgNVBAMTImFjY291bnRzLmFjY2Vzc2NvbnRyb2wud2luZG93cy5uZXQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCJ1xIxf0JWqiKh2J5CHs4FutjtysWKqwC3H4qOWlTv7QH13INbvN6KI+fHtIBvQnx8GZvs7Xa/hTgEcglhKIVHHEZoWk6+lqs3AIl3EImTr07OzTcwFyg7SntxhBBkYITweMEXvP2ZVQYi+BJgG+3CDt9S3aT7z2K06AjPOkXwmb2cEc2BI7xm+/32kXUh94fJWjR4hMhRtCs9i9bmsDR4rKNFfKB4oUVJKdpnB4o4mYJ1dfq6d1HMM5tQ/esxu/4gUwM2wziP9oEv7m8NUqmfsC7syEFuvzfG/qjpEUNbJyWONNoalgRP+54v+iv56HJ/zhlEdVmmo5l58821l5l/AgMBAAGjITAfMB0GA1UdDgQWBBQNpQkCxHV1tY+HilDxZ/NuMvS8BDANBgkqhkiG9w0BAQsFAAOCAQEATelFDXIrDxeJ+G+3ERppylvf/oEBkIsNnii8sg+zVltSJ4TC4OBrGC80vwDkxQVOGJBjYk9sYnMsHkKeYkFsCOK25DbhDB2GLhFnNUYzctPrwd/HLcFFgrNxM5xNvGdEQq5uRhELD0mJg3tfaWlVXOpLXifpjvE7sdT3wDzMl9S5iefqS00Qk3OwKPw9i9nfRsmawTaIQScxuX4RHS9K0Xjilr1K0FN8JSNXSLD7PjmBYcJqa/jeMsK+J7SyLXJr3rkMCD5UOsy18+QEpwzJhVtqgcOlKrgtN4W6JQCNfLWYUy1id6/YhIpJyU/9zHpfCR8TFNsMpdl0FG7IzrHYiA==
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
LOCALEOF

echo "✓ Created local config file"

# Copy to remote server
scp /tmp/kimai_local.yaml root@${KIMAI_HOST}:/tmp/

# Backup and replace on remote
ssh root@${KIMAI_HOST} "cd /var/www/kimai && cp config/packages/local.yaml config/packages/local.yaml.authentik-backup && mv /tmp/kimai_local.yaml config/packages/local.yaml"

echo "✓ Updated local.yaml on server"

# Clear cache and restart
ssh root@${KIMAI_HOST} "cd /var/www/kimai && rm -rf var/cache/* && bin/console cache:clear --env=prod && systemctl restart php8.3-fpm"

echo "✓ Cleared cache and restarted PHP-FPM"

# Cleanup
rm /tmp/kimai_local.yaml

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "The button should now say 'Login with Microsoft'"
echo "Test at: https://time.cloudigan.net"
echo ""
