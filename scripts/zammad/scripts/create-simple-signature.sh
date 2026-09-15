#!/bin/bash
set -euo pipefail
TOKEN="${ZAMMAD_API_TOKEN:?Set ZAMMAD_API_TOKEN (Zammad → Profile → Token Access)}"

# Create a simple, clean signature for Cloudigan Support

curl -X POST \
  -H "Authorization: Token ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  https://support.cloudigan.net/api/v1/signatures << 'EOF'
{
  "name": "Cloudigan Simple",
  "body": "<p>--<br>Best regards,<br><strong>Cloudigan Support Team</strong></p><p>Cloudigan IT Solutions<br><em>We do IT so you don't have to.</em></p><p>Email: <a href=\"mailto:support@cloudigan.com\">support@cloudigan.com</a><br>Web: <a href=\"https://www.cloudigan.com\">www.cloudigan.com</a></p>",
  "active": true
}
EOF
