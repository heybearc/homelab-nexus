#!/usr/bin/env bash
# Phase 2: Primary zone on Technitium + secondary AXFR on TrueNAS standby
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DNS_ZONE="${DNS_ZONE:-cloudigan.net}"
TECH_PRIMARY="${TECHNITIUM_PRIMARY_IP:-10.92.3.10}"
TECH_STANDBY="${TECHNITIUM_STANDBY_IP:-10.92.3.203}"
TECH_URL="${TECHNITIUM_URL:-http://${TECH_PRIMARY}:5380}"
TECH_STANDBY_URL="${TECHNITIUM_STANDBY_URL:-http://${TECH_STANDBY}:5380}"
TSIG_NAME="${DNS_TSIG_KEY_NAME:-cloudigan-xfr}"
TSIG_SECRET="${DNS_TSIG_SECRET:-$(openssl rand -base64 32)}"

CSV="/tmp/cloudigan-net-zone.csv"
ZONE_FILE="/tmp/cloudigan-net-zone.txt"

login() {
  TECHNITIUM_URL="$TECH_URL" "$SCRIPT_DIR/technitium-api.sh" token
}

login_standby() {
  TECHNITIUM_URL="$TECH_STANDBY_URL" "$SCRIPT_DIR/technitium-api.sh" token
}

api_ok() {
  local resp="$1"
  echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null
}

echo "=== Export zone from dc-01 ==="
"$SCRIPT_DIR/export-dc01-zone.sh" "$CSV" "$ZONE_FILE"

echo "=== Login Technitium primary (${TECH_PRIMARY}) ==="
TOKEN=$(login)

echo "=== Create primary zone ${DNS_ZONE} (idempotent) ==="
CREATE=$(curl -sS "${TECH_URL}/api/zones/create?token=${TOKEN}&zone=${DNS_ZONE}&type=Primary")
api_ok "$CREATE" 2>/dev/null || echo "$CREATE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('errorMessage', d))" || true

echo "=== Import zone file ==="
IMPORT=$(curl -sS -X POST "${TECH_URL}/api/zones/import?token=${TOKEN}&zone=${DNS_ZONE}&overwrite=true" \
  -H "Content-Type: text/plain" --data-binary @"${ZONE_FILE}")
echo "$IMPORT" | python3 -m json.tool 2>/dev/null || echo "$IMPORT"

echo "=== Configure TSIG key on primary ==="
TSIG_ROW="${TSIG_NAME}|${TSIG_SECRET}|hmac-sha256"
SET_PRIMARY=$(curl -sS "${TECH_URL}/api/settings/set?token=${TOKEN}" \
  --data-urlencode "tsigKeys=${TSIG_ROW}")
api_ok "$SET_PRIMARY" || { echo "$SET_PRIMARY"; exit 1; }

echo "=== Ensure primary listens on IPv4 TCP 53 (AXFR) ==="
curl -sS "${TECH_URL}/api/settings/set?token=${TOKEN}" \
  --data-urlencode "dnsServerLocalEndPoints=${TECH_PRIMARY}:53,0.0.0.0:53" \
  --data-urlencode "ipv6Mode=Disabled" >/dev/null
ssh prox "pct exec 145 -- docker restart technitium" >/dev/null 2>&1 || true
sleep 8
TOKEN=$(login)

echo "=== Allow AXFR from TrueNAS (.203 + host .200) + NOTIFY ==="
OPTS=$(curl -sS "${TECH_URL}/api/zones/options/set?token=${TOKEN}" \
  --data-urlencode "zone=${DNS_ZONE}" \
  --data-urlencode "zoneTransfer=UseSpecifiedNetworkACL" \
  --data-urlencode "zoneTransferNetworkACL=${TECH_STANDBY},10.92.3.200" \
  --data-urlencode "zoneTransferTsigKeyNames=false" \
  --data-urlencode "notify=SpecifiedNameServers" \
  --data-urlencode "notifyNameServers=${TECH_STANDBY}")
api_ok "$OPTS" || { echo "$OPTS"; exit 1; }

echo "=== Configure TSIG + secondary zone on standby (${TECH_STANDBY}) ==="
STANDBY_TOKEN=$(login_standby)
curl -sS "${TECH_STANDBY_URL}/api/settings/set?token=${STANDBY_TOKEN}" \
  --data-urlencode "tsigKeys=${TSIG_ROW}" >/dev/null

SEC=$(curl -sS "${TECH_STANDBY_URL}/api/zones/create?token=${STANDBY_TOKEN}" \
  --data-urlencode "zone=${DNS_ZONE}" \
  --data-urlencode "type=Secondary" \
  --data-urlencode "primaryNameServerAddresses=${TECH_PRIMARY}" \
  --data-urlencode "zoneTransferProtocol=Tcp")
api_ok "$SEC" 2>/dev/null || echo "$SEC" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('errorMessage', d))" || true

echo "=== Trigger zone resync on standby ==="
curl -sS "${TECH_STANDBY_URL}/api/zones/resync?token=${STANDBY_TOKEN}&zone=${DNS_ZONE}" >/dev/null 2>&1 || true

echo "=== Verify ==="
sleep 3
echo -n "Primary SOA: "; dig @"${TECH_PRIMARY}" "${DNS_ZONE}" SOA +short | head -1
echo -n "Standby SOA: "; dig @"${TECH_STANDBY}" "${DNS_ZONE}" SOA +short | head -1
echo -n "Standby n8n:   "; dig @"${TECH_STANDBY}" "n8n.${DNS_ZONE}" A +short | head -1

cat <<EOF

TSIG (save to .env):
  DNS_TSIG_KEY_NAME=${TSIG_NAME}
  DNS_TSIG_SECRET=${TSIG_SECRET}

NPM UI hostnames (A → 10.92.3.3 on dc-01 / Technitium):
  dns.cloudigan.net       → NPM → ${TECH_PRIMARY}:5380
  dns-2.cloudigan.net     → NPM → ${TECH_STANDBY}:5380
  dnsfilter.cloudigan.net → NPM → 10.92.3.11:3000
  dnsfilter-2.cloudigan.net → NPM → 10.92.3.204:3000
EOF
