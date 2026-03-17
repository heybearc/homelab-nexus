#!/bin/bash
# Add SendGrid DNS records to cloudigan.com via Wix DNS API

set -e

WIX_ACCOUNT_ID="e1c7c474-4d12-462d-b03a-6ad2fc003e59"
WIX_API_KEY="IST.eyJraWQiOiJQb3pIX2FDMiIsImFsZyI6IlJTMjU2In0.eyJkYXRhIjoie1wiaWRcIjpcIjc4MWZlOWMxLWI4YmItNDIyYS1hNWM5LTZjMTRmMjhhYThiNFwiLFwiaWRlbnRpdHlcIjp7XCJ0eXBlXCI6XCJhcHBsaWNhdGlvblwiLFwiaWRcIjpcIjIyOGMyMmE5LWQzMzEtNGY1Yi05M2MyLTg1NjM1YjY3YjY5OVwifSxcInRlbmFudFwiOntcInR5cGVcIjpcImFjY291bnRcIixcImlkXCI6XCI5NWIyMTM3Yy00ZWEzLTRjMjEtODczOS04ZTg1N2I3NTcwZGJcIn19IiwiaWF0IjoxNzczNDk4MTAxfQ.gkaWBODl9URgx1Q2guH9oBTukR0hmJv11VealLupp1SYlShKUYuGjoKPhFRiCsKlySGViatKYRIR-50Krl2PLgXPKa2k_Ua1XHBnRpZTIvqtw-8rvc6tfeMVfSisi9g8iEeqL0nyKNSEAXoPecu3nNEQQ2LAJbGnqCDZMybadm6b1I8C1P6fkdXCB4TitrDB2uCG3codM5_F6g80Z-BSzL5qzMcPfsKeEakV37IK4DfLV-oS3G9Sh_70he-JNMgYFPOP4soWdd7JHErtBksOv28TcqmF6bjdcsfko9kIAI5FIpbOdPGpWkdACMqO3VCkF5ssAZiPQXC8RS3eRbGWJQ"

echo "Adding SendGrid DNS records to cloudigan.com..."

curl -X PATCH 'https://www.wixapis.com/domains/v1/dns-zones/cloudigan.com' \
  -H "wix-account-id: ${WIX_ACCOUNT_ID}" \
  -H "Authorization: ${WIX_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{
    "additions": [
      {"type": "CNAME", "hostName": "url3953.cloudigan.com", "values": ["sendgrid.net"], "ttl": 3600},
      {"type": "CNAME", "hostName": "61130637.cloudigan.com", "values": ["sendgrid.net"], "ttl": 3600},
      {"type": "CNAME", "hostName": "em8063.cloudigan.com", "values": ["u61130637.wl138.sendgrid.net"], "ttl": 3600},
      {"type": "CNAME", "hostName": "s1._domainkey.cloudigan.com", "values": ["s1.domainkey.u61130637.wl138.sendgrid.net"], "ttl": 3600},
      {"type": "CNAME", "hostName": "s2._domainkey.cloudigan.com", "values": ["s2.domainkey.u61130637.wl138.sendgrid.net"], "ttl": 3600}
    ],
    "deletions": [
      {"type": "TXT", "hostName": "_dmarc.cloudigan.com", "values": ["v=DMARC1; p=quarantine; rua=mailto:re+l6nzji6h0kd@dmarc.postmarkapp.com; ruf=mailto:cory@cloudigan.com; fo=1"], "ttl": 3600}
    ]
  }'

echo ""
echo "Adding updated DMARC record..."

curl -X PATCH 'https://www.wixapis.com/domains/v1/dns-zones/cloudigan.com' \
  -H "wix-account-id: ${WIX_ACCOUNT_ID}" \
  -H "Authorization: ${WIX_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{
    "additions": [
      {"type": "TXT", "hostName": "_dmarc.cloudigan.com", "values": ["v=DMARC1; p=quarantine; rua=mailto:re+l6nzji6h0kd@dmarc.postmarkapp.com,mailto:cory@cloudigan.com; ruf=mailto:cory@cloudigan.com; fo=1; aspf=r; adkim=r"], "ttl": 3600}
    ]
  }'

echo ""
echo "✅ DNS records added successfully!"
echo ""
echo "Next steps:"
echo "1. Wait 5-10 minutes for DNS propagation"
echo "2. Verify in SendGrid dashboard"
echo "3. Get SendGrid API key"
