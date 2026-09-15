#!/usr/bin/env bash
# Add/update A record on Technitium (authoritative for cloudigan.net lab zones).
# Replaces former dc-01 write path for lab DNS.
#
# Usage:
#   ./dns-add-record.sh <fqdn-or-hostname> <ip>
#   DNS_ZONE=cloudigan.net ./dns-add-record.sh jellyfin 10.92.3.20
#
# Requires: TECHNITIUM_API_TOKEN (and optional TECHNITIUM_URL)
set -euo pipefail

DOMAIN="${1:-}"
IP_ADDRESS="${2:-}"
DNS_ZONE="${DNS_ZONE:-cloudigan.net}"
TECHNITIUM_URL="${TECHNITIUM_URL:-http://10.92.3.10:5380}"
TECHNITIUM_API_TOKEN="${TECHNITIUM_API_TOKEN:-}"

if [[ -z "$DOMAIN" || -z "$IP_ADDRESS" ]]; then
  echo "Usage: $0 <domain> <ip_address>"
  exit 1
fi

if [[ -z "$TECHNITIUM_API_TOKEN" && -f "${HOME}/.cache/technitium-token" ]]; then
  TECHNITIUM_API_TOKEN="$(cat "${HOME}/.cache/technitium-token")"
fi
if [[ -z "$TECHNITIUM_API_TOKEN" ]]; then
  echo "ERROR: Set TECHNITIUM_API_TOKEN"
  exit 1
fi

# Normalize to FQDN
if [[ "$DOMAIN" != *.* ]]; then
  FQDN="${DOMAIN}.${DNS_ZONE}"
elif [[ "$DOMAIN" == *".${DNS_ZONE}" ]]; then
  FQDN="$DOMAIN"
else
  FQDN="$DOMAIN"
fi

echo "Adding Technitium A: ${FQDN} → ${IP_ADDRESS}"

RESP=$(curl -sS "${TECHNITIUM_URL}/api/zones/records/add" \
  --data-urlencode "token=${TECHNITIUM_API_TOKEN}" \
  --data-urlencode "domain=${FQDN}" \
  --data-urlencode "type=A" \
  --data-urlencode "ipAddress=${IP_ADDRESS}" \
  --data-urlencode "ttl=300" \
  --data-urlencode "overwrite=true" \
  --data-urlencode "ptr=false")

STATUS=$(printf '%s' "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || true)
if [[ "$STATUS" != "ok" ]]; then
  echo "ERROR: Technitium add failed: $RESP"
  exit 1
fi

echo "✓ Record saved"
dig +short +time=2 "$FQDN" @"${TECHNITIUM_URL#http://}" 2>/dev/null | sed 's|:5380||' || \
  dig +short +time=2 "$FQDN" @10.92.3.10
