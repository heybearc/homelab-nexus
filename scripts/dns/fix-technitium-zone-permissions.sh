#!/usr/bin/env bash
# Fix Technitium zone visibility (admin/corya missing per-zone + group permissions).
#
# Usage:
#   TOKEN=<session-token> ./fix-technitium-zone-permissions.sh
#   ./fix-technitium-zone-permissions.sh --bootstrap   # resets auth to ChangeMe-DNS-2026 (destructive)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TECH_URL="${TECHNITIUM_URL:-http://10.92.3.10:5380}"
TECH_STANDBY_URL="${TECHNITIUM_STANDBY_URL:-http://10.92.3.203:5380}"
ZONES=(
  cloudigan.net
  theoshift.com
  quantshift.io
  factorpoint.io
  helpfulhirschventures.com
  ldctools.com
)

api() {
  local url="$1"; shift
  curl -sS "${url}" "$@"
}

fix_with_token() {
  local base="$1" token="$2" label="$3"
  echo "=== Fixing ${label} ==="

  api "${base}/api/admin/users/set" \
    --data-urlencode "token=${token}" \
    --data-urlencode "user=admin" \
    --data-urlencode "memberOfGroups=Administrators,DNS Administrators" | python3 -c "import sys,json; d=json.load(sys.stdin); print('admin groups:', d.get('status'), d.get('errorMessage',''))"

  api "${base}/api/admin/users/set" \
    --data-urlencode "token=${token}" \
    --data-urlencode "user=corya" \
    --data-urlencode "memberOfGroups=Administrators,DNS Administrators" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('corya groups:', d.get('status'), d.get('errorMessage',''))" || echo "corya: skipped (user may not exist)"

  for zone in "${ZONES[@]}"; do
    api "${base}/api/zones/permissions/set" \
      --data-urlencode "token=${token}" \
      --data-urlencode "zone=${zone}" \
      --data-urlencode "userPermissions=admin|true|true|true|corya|true|true|true" \
      --data-urlencode "groupPermissions=Administrators|true|true|true|DNS Administrators|true|true|true|Everyone|true|false|false" \
      >/dev/null
    echo "  zone permissions: ${zone}"
  done

  api "${base}/api/zones/list?token=${token}" | python3 -c "
import sys,json
d=json.load(sys.stdin)
zones=d.get('response',{}).get('zones',[])
print(f'  visible zones: {len(zones)}')
for z in sorted(zones, key=lambda x: x['name']):
    if z['type'] in ('Primary','Secondary'):
        print(f\"    {z['name']} ({z['type']})\")
"
}

bootstrap_primary() {
  echo "Bootstrapping primary auth (temporary — set password again in UI after)..."
  ssh prox "pct exec 145 -- bash -s" <<'REMOTE'
set -euo pipefail
cd /opt/technitium/data
cp -a auth.config "auth.config.backup-$(date +%Y%m%d%H%M%S)"
docker stop technitium
rm -f auth.config
docker start technitium
REMOTE
  sleep 6
  local resp pass=admin
  resp=$(api "${TECH_URL}/api/user/login" -d "user=admin&pass=${pass}")
  if ! echo "$resp" | python3 -c "import sys,json; json.load(sys.stdin)['token']" >/dev/null 2>&1; then
    pass=ChangeMe-DNS-2026
    resp=$(api "${TECH_URL}/api/user/login" -d "user=admin&pass=${pass}")
  fi
  TOKEN=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
  fix_with_token "$TECH_URL" "$TOKEN" "primary (dns)"
}

bootstrap_standby() {
  echo "Bootstrapping standby auth..."
  ssh truenas 'midclt call cronjob.create "{\"user\":\"root\",\"command\":\"cp -a /mnt/media-pool/vms/dns-stack/technitium-standby/data/auth.config /mnt/media-pool/vms/dns-stack/technitium-standby/data/auth.config.backup-$(date +%Y%m%d%H%M%S) && docker stop technitium-standby && rm -f /mnt/media-pool/vms/dns-stack/technitium-standby/data/auth.config && docker start technitium-standby\",\"description\":\"bootstrap-standby-auth\",\"enabled\":true,\"stdout\":true,\"stderr\":true,\"schedule\":{\"minute\":\"*\",\"hour\":\"*\",\"dom\":\"*\",\"month\":\"*\",\"dow\":\"*\"}}"' >/dev/null
  local id
  id=$(ssh truenas 'midclt call cronjob.query' | python3 -c "import sys,json; jobs=json.load(sys.stdin); print([j['id'] for j in jobs if j.get('description')=='bootstrap-standby-auth'][-1])")
  ssh truenas "midclt call cronjob.run ${id} true" >/dev/null
  ssh truenas "midclt call cronjob.delete ${id}" >/dev/null
  sleep 6
  TOKEN=$(api "${TECH_STANDBY_URL}/api/user/login" -d "user=admin&pass=ChangeMe-DNS-2026" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
  fix_with_token "$TECH_STANDBY_URL" "$TOKEN" "standby (dns-2)"
}

if [[ "${1:-}" == "--bootstrap" ]]; then
  bootstrap_primary
  bootstrap_standby
  echo ""
  echo "Done. Login: admin / admin (no 2FA). Change password in UI immediately."
  exit 0
fi

TOKEN="${TOKEN:-}"
if [[ -z "$TOKEN" ]]; then
  echo "Set TOKEN from browser console while logged in: localStorage.getItem('token')"
  echo "Or run: $0 --bootstrap  (resets auth — destructive)"
  exit 1
fi

fix_with_token "$TECH_URL" "$TOKEN" "primary (dns)"
