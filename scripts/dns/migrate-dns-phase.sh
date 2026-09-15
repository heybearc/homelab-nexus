#!/usr/bin/env bash
# Phased DNS migration with state tracking — see documentation/DNS-REDUNDANCY-MIGRATION.md
# Usage:
#   ./migrate-dns-phase.sh 0          # bootstrap dc-01 records for new hostnames
#   ./migrate-dns-phase.sh 2          # import zone to Technitium
#   ./migrate-dns-phase.sh 3          # document adguard upstream (manual/API)
#   ./migrate-dns-phase.sh 6 --apply  # final DHCP cutover checklist
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="${DNS_MIGRATION_STATE_DIR:-/opt/dns-migration}"
STATE_FILE="${STATE_DIR}/state.json"

# shellcheck source=/dev/null
[[ -f "$REPO_ROOT/.env" ]] && source "$REPO_ROOT/.env"

DNS_ZONE="${DNS_ZONE:-cloudigan.net}"
DC01_HOST="${DC01_HOST:-10.92.0.10}"
DC01_USER="${DC01_USER:-cory@cloudigan.com}"

TECH_IP="${TECHNITIUM_PRIMARY_IP:-10.92.3.10}"
TECH_STANDBY_IP="${TECHNITIUM_STANDBY_IP:-10.92.3.203}"
AG_IP="${ADGUARD_PRIMARY_IP:-10.92.3.11}"
AG_STANDBY_IP="${ADGUARD_STANDBY_IP:-10.92.3.204}"

save_state() {
  local phase="$1" note="$2"
  mkdir -p "$STATE_DIR"
  python3 - <<PY
import json, os, datetime
p = "${STATE_FILE}"
data = {}
if os.path.exists(p):
    with open(p) as f: data = json.load(f)
data["phase_${phase}_completed"] = datetime.datetime.utcnow().isoformat() + "Z"
data["phase_${phase}_note"] = """${note}"""
with open(p, "w") as f: json.dump(data, f, indent=2)
print("State saved:", p)
PY
}

phase0_bootstrap() {
  echo "=== Phase 0: dc-01 bootstrap A records (UI → NPM, same as adguard) ==="
  local npm_ip="10.92.3.3"
  local records=(
    "dns:${npm_ip}"
    "dns-2:${npm_ip}"
    "dnsfilter:${npm_ip}"
    "dnsfilter-2:${npm_ip}"
  )
  for r in "${records[@]}"; do
    local name="${r%%:*}" ip="${r##*:}"
    echo "Adding ${name}.${DNS_ZONE} → ${ip}"
    "$SCRIPT_DIR/update-dc01-dns.sh" add "$name" "$ip" || true
  done
  save_state 0 "dc-01 bootstrap records for technitium + standby adguard"
}

phase2_import() {
  echo "=== Phase 2: Export dc-01 → import Technitium ==="
  local csv="/tmp/cloudigan-net-zone.csv"
  "$SCRIPT_DIR/export-dc01-zone.sh" "$csv"
  export TECHNITIUM_URL="http://${TECH_IP}:5380"
  tail -n +2 "$csv" | while IFS=, read -r fqdn ip; do
    [[ -z "$fqdn" || -z "$ip" ]] && continue
    local host="${fqdn%.${DNS_ZONE}}"
    [[ "$host" == "$DNS_ZONE" ]] && host="@"
    echo "Import ${host} → ${ip}"
    "$SCRIPT_DIR/technitium-api.sh" add "$host" "$ip" || true
  done
  echo "Verify secondary zone AXFR on Technitium standby (${TECH_STANDBY_IP}:5380)"
  save_state 2 "zone imported from dc-01"
}

phase3_adguard() {
  echo "=== Phase 3: AdGuard primary upstream → Technitium ==="
  cat <<EOF
Manual / API steps on http://${AG_IP}:3000:
  1. Settings → DNS settings
  2. Upstream DNS servers: ${TECH_IP} only (fallback ${TECH_STANDBY_IP})
     Do NOT add public resolvers here — Technitium forwards public queries (same as dc-01).
  3. DNS rewrites for ${DNS_ZONE} are NOT needed if Technitium owns the zone

On standby AdGuard http://${AG_STANDBY_IP}:3000:
  1. Bind DNS to ${AG_STANDBY_IP}
  2. Upstream local first: ${TECH_STANDBY_IP}, fallback ${TECH_IP}
  3. Export/import blocklists from primary AdGuard
EOF
  save_state 3 "adguard upstream instructions printed"
}

phase6_cutover() {
  echo "=== Phase 6: DHCP DNS cutover checklist ==="
  cat <<EOF
Omada / gateway DHCP DNS option 6:
  BEFORE (rollback state — record current values in state file):
    DNS1: (current — likely dc-01 ${DC01_HOST} or AdGuard ${AG_IP})
    DNS2: (current or empty)

  Phase 5 (add secondary only):
    DNS2: ${AG_STANDBY_IP}  (dnsfilter-2 / 10.92.3.204)

  Phase 6 (full cutover):
    DNS1: ${AG_IP}          (dnsfilter / 10.92.3.11)
    DNS2: ${AG_STANDBY_IP}  (dnsfilter-2 / 10.92.3.204)

Rollback: ./scripts/dns/rollback-dns-cutover.sh

Test from a client after change:
  nslookup n8n.${DNS_ZONE} ${AG_IP}
  nslookup n8n.${DNS_ZONE} ${AG_STANDBY_IP}
EOF
  if [[ "${1:-}" == "--apply" ]]; then
    echo ""
    echo "Apply DHCP changes in Omada UI now, then press Enter to record cutover."
    read -r
    save_state 6 "dhcp cutover applied manually"
  else
    echo "Re-run with --apply after changing Omada DHCP."
  fi
}

PHASE="${1:-}"
shift || true
case "$PHASE" in
  0) phase0_bootstrap ;;
  2) phase2_import ;;
  3) phase3_adguard ;;
  6) phase6_cutover "$@" ;;
  *)
    echo "Usage: $0 0|2|3|6 [--apply]"
    exit 1
    ;;
esac
