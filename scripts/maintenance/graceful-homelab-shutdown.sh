#!/usr/bin/env bash
# Graceful homelab shutdown for rack relocation or maintenance.
# Runs from your Mac via the `prox` SSH alias.
#
# Usage:
#   ./scripts/maintenance/graceful-homelab-shutdown.sh            # dry-run (default)
#   ./scripts/maintenance/graceful-homelab-shutdown.sh --execute  # actually shut down
#
# After this script completes on Proxmox:
#   1. Shut down TrueNAS:  ssh truenas 'sudo shutdown -h now'
#   2. Power off Proxmox:  ssh prox 'shutdown -h now'
#   3. Power off switch/UPS last after hosts are off

set -euo pipefail

PROX="${PROX:-prox}"
EXECUTE=false
VM_TIMEOUT=300
LXC_TIMEOUT=180
BACKUP_WAIT_MAX=7200   # 2 hours
SLEEP_BETWEEN=5

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}ℹ${NC}  $*"; }
ok()    { echo -e "${GREEN}✓${NC}  $*"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $*"; }
err()   { echo -e "${RED}✗${NC}  $*" >&2; }

usage() {
  sed -n '2,12p' "$0"
  exit "${1:-0}"
}

for arg in "$@"; do
  case "$arg" in
    --execute|-x) EXECUTE=true ;;
    --help|-h) usage 0 ;;
    *) err "Unknown option: $arg"; usage 1 ;;
  esac
done

remote() {
  ssh -o ConnectTimeout=15 "$PROX" "$@"
}

run_cmd() {
  local label="$1"
  shift
  if $EXECUTE; then
    info "$label"
    remote "$@"
  else
    info "[dry-run] $label"
    info "          → ssh $PROX '$*'"
  fi
}

shutdown_vm() {
  local vmid="$1"
  run_cmd "Graceful VM shutdown $vmid (timeout ${VM_TIMEOUT}s)" \
    "qm shutdown $vmid --timeout $VM_TIMEOUT --forceStop 1 || qm stop $vmid"
}

shutdown_lxc() {
  local ctid="$1"
  run_cmd "Graceful LXC shutdown $ctid (timeout ${LXC_TIMEOUT}s)" \
    "pct shutdown $ctid --timeout $LXC_TIMEOUT --forceStop 1 || pct stop $ctid"
}

stop_postgres() {
  local ctid="$1" role="$2"
  if $EXECUTE; then
    info "Stopping PostgreSQL inside CT$ctid ($role)"
    remote "pct exec $ctid -- systemctl stop postgresql" || \
      shutdown_lxc "$ctid"
  else
    info "[dry-run] systemctl stop postgresql in CT$ctid ($role)"
  fi
}

wait_for_backup_lock() {
  info "Checking for active vzdump / backup locks..."
  if remote "pct list | awk '\$1==141 && \$3==\"backup\" {found=1} END{exit !found}'"; then
    warn "CT141 (netbox) is locked for backup"
    if ! $EXECUTE; then
      warn "Dry-run: would wait for backup to finish before shutting down CT141"
      return 0
    fi
    local waited=0
    while remote "pct list | awk '\$1==141 && \$3==\"backup\" {found=1} END{exit !found}'"; do
      if (( waited >= BACKUP_WAIT_MAX )); then
        err "Backup lock still present after ${BACKUP_WAIT_MAX}s. Abort or cancel backup in Proxmox UI."
        exit 1
      fi
      sleep 30
      waited=$((waited + 30))
      info "  waiting for backup... (${waited}s)"
    done
  fi
  ok "No backup lock on CT141"
}

wait_for_stopped() {
  local kind="$1" id="$2" max="${3:-600}"
  local waited=0
  while remote "${kind} status $id 2>/dev/null | grep -q running"; do
    if (( waited >= max )); then
      warn "$kind $id still running after ${max}s"
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
  ok "$kind $id stopped"
}

preflight() {
  info "=== Pre-flight ==="
  remote "hostname && uptime"
  echo ""
  remote "echo 'Running VMs:' && qm list | awk 'NR==1 || \$3==\"running\"'"
  echo ""
  remote "echo 'Running LXCs:' && pct list | awk 'NR==1 || \$2==\"running\"'"
  echo ""
  remote "ps aux | grep -E 'vzdump|vzdump' | grep -v grep || echo 'No vzdump process visible'"
  echo ""
}

main() {
  if $EXECUTE; then
    warn "EXECUTE mode — this will shut down the homelab"
    read -r -p "Type 'shutdown homelab' to continue: " confirm
    [[ "$confirm" == "shutdown homelab" ]] || { err "Aborted"; exit 1; }
  else
    warn "DRY-RUN mode — pass --execute to shut down for real"
  fi

  preflight
  wait_for_backup_lock

  info "=== Phase 1: Edge / traffic (stop new connections) ==="
  for ct in 121 136 139 140; do
    shutdown_lxc "$ct"
    $EXECUTE && sleep "$SLEEP_BETWEEN"
  done

  info "=== Phase 2: Application containers ==="
  # All running app/workload LXCs except DB, media, edge (handled separately)
  app_cts=(111 115 119 132 134 170 171 172 180 181 182 183 184 185 186 187 188 189 190 191 192 193 194 196 197 198 199 150 152 153)
  for ct in "${app_cts[@]}"; do
    if remote "pct status $ct 2>/dev/null | grep -q running"; then
      shutdown_lxc "$ct"
      $EXECUTE && sleep "$SLEEP_BETWEEN"
    fi
  done

  info "=== Phase 3: Media / downloads (Plex gets extra time) ==="
  for ct in 127 124 125 120 129 130; do
    if remote "pct status $ct 2>/dev/null | grep -q running"; then
      shutdown_lxc "$ct"
      $EXECUTE && sleep "$SLEEP_BETWEEN"
    fi
  done
  if remote "pct status 128 2>/dev/null | grep -q running"; then
    info "Shutting down Plex (CT128) — allow up to ${LXC_TIMEOUT}s for clean exit"
    shutdown_lxc 128
    $EXECUTE && wait_for_stopped pct 128 "$((LXC_TIMEOUT + 60))" || true
  fi

  info "=== Phase 4: Databases (replica → primary → netbox) ==="
  if remote "pct status 151 2>/dev/null | grep -q running"; then
    stop_postgres 151 "replica"
    $EXECUTE && wait_for_stopped pct 151 120 || true
  fi
  if remote "pct status 131 2>/dev/null | grep -q running"; then
    stop_postgres 131 "primary"
    $EXECUTE && wait_for_stopped pct 131 120 || true
  fi
  if remote "pct status 141 2>/dev/null | grep -q running"; then
    shutdown_lxc 141
    $EXECUTE && wait_for_stopped pct 141 120 || true
  fi

  info "=== Phase 5: Remaining LXCs ==="
  if remote "pct status 142 2>/dev/null | grep -q running"; then
    shutdown_lxc 142
  fi
  # Catch anything still running
  while read -r ctid; do
    [[ -n "$ctid" ]] || continue
    warn "Stopping leftover running LXC: $ctid"
    shutdown_lxc "$ctid"
  done < <(remote "pct list | awk 'NR>1 && \$2==\"running\" {print \$1}'")

  info "=== Phase 6: VMs (guest-agent graceful shutdown) ==="
  for vm in 102 104 106 107 108; do
    if remote "qm status $vm 2>/dev/null | grep -q running"; then
      shutdown_vm "$vm"
      $EXECUTE && wait_for_stopped qm "$vm" "$((VM_TIMEOUT + 60))" || true
    fi
  done

  echo ""
  if $EXECUTE; then
    ok "Proxmox guests shut down"
    echo ""
    warn "Manual steps remaining:"
    echo "  1. TrueNAS:  ssh truenas 'sudo shutdown -h now'"
    echo "  2. Verify:   ssh prox 'qm list; pct list'"
    echo "  3. Proxmox:  ssh prox 'shutdown -h now'"
    echo "  4. Power off switch / PDU after hosts are off"
    echo ""
    warn "Before powering back on: re-seat drives, reconnect network, verify cable labels"
  else
    ok "Dry-run complete — review phases above, then re-run with --execute"
  fi
}

main "$@"
