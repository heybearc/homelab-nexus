#!/usr/bin/env bash
# Temporarily move LXCs between vmbr0923 (10G) and vmbr923 (1G eno1.923).
# Same VLAN 923 / same IPs — only the bridge name changes.
#
# Usage:
#   ./scripts/maintenance/migrate-bridge-923-temp.sh to-1g     # vmbr0923 -> vmbr923
#   ./scripts/maintenance/migrate-bridge-923-temp.sh to-10g      # vmbr923 -> vmbr0923 (revert)
#   ./scripts/maintenance/migrate-bridge-923-temp.sh to-1g --dry-run

set -euo pipefail

PROX="${PROX:-prox}"
MODE="${1:-}"
DRY_RUN=false
STOP_TIMEOUT=120

FROM_BRIDGE=""
TO_BRIDGE=""

usage() {
  sed -n '2,10p' "$0"
  exit 1
}

[[ -n "$MODE" ]] || usage

for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

case "$MODE" in
  to-1g)  FROM_BRIDGE=vmbr0923; TO_BRIDGE=vmbr923 ;;
  to-10g) FROM_BRIDGE=vmbr923;  TO_BRIDGE=vmbr0923 ;;
  *) usage ;;
esac

remote() { ssh -o ConnectTimeout=20 "$PROX" "$@"; }

migrate_ct() {
  local id="$1"
  local net line was_running

  net=$(remote "pct config $id 2>/dev/null | grep '^net0'" || true)
  [[ -n "$net" ]] || return 0
  [[ "$net" == *"bridge=${FROM_BRIDGE}"* ]] || return 0

  line=$(echo "$net" | sed "s/^net0: //; s/bridge=${FROM_BRIDGE}/bridge=${TO_BRIDGE}/")
  was_running=$(remote "pct status $id 2>/dev/null | awk '{print \$2}'" || echo stopped)

  if $DRY_RUN; then
    echo "[dry-run] CT$id ($was_running): bridge ${FROM_BRIDGE} -> ${TO_BRIDGE}"
    return 0
  fi

  echo "=== CT$id ($was_running) ==="
  if [[ "$was_running" == "running" ]]; then
    remote "pct stop $id" || remote "pct stop $id --skiplock"
  fi
  remote "pct set $id -net0 '$line'"
  if [[ "$was_running" == "running" ]]; then
    remote "pct start $id"
  fi
}

# Critical first on migrate to 1g; reverse order when reverting to 10g
CRITICAL_ORDER=(131 140 136 139 121 150 151)

main() {
  echo "Migrate ${FROM_BRIDGE} -> ${TO_BRIDGE} on $PROX"
  $DRY_RUN && echo "(dry-run)"

  remote "ip -br link show vmbr923 vmbr0923 eno1.923 2>/dev/null || true"

  ids=$(remote "pct list | awk 'NR>1 {print \$1}'")
  ordered=()

  for id in "${CRITICAL_ORDER[@]}"; do
    ordered+=("$id")
  done
  for id in $ids; do
    skip=false
    for c in "${CRITICAL_ORDER[@]}"; do
      [[ "$id" == "$c" ]] && skip=true && break
    done
    $skip && continue
    [[ "$id" == "142" ]] && continue  # omada on vmbr920
    ordered+=("$id")
  done

  for id in "${ordered[@]}"; do
    migrate_ct "$id"
  done

  if ! $DRY_RUN; then
    echo ""
    echo "=== Summary ==="
    remote "pct list | awk 'NR>1 {print \$1}' | while read id; do pct config \$id 2>/dev/null | grep '^net0' | grep -oP 'bridge=\K[^,]+' | xargs echo CT\$id; done | sort | uniq -c"
    echo ""
    remote "ping -c 2 10.92.3.1 2>&1 | tail -2"
  fi
}

main
