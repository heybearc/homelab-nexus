#!/bin/bash
# Drain prox2 guests to prox1. PVE 9 has no LXC live migrate — use --restart.
# Pause postgres watchdog + replica keepalived around CT131 so VIP does not land on a replica.
set -u
DEST="${1:-prox1}"
LOG=/tmp/drain-prox2-to-prox1.log
PROX3=10.92.0.7
PROX1=10.92.0.5
CTS=(111 115 119 120 124 129 130 132 139 140 141 142 153 170 171 181 183 185 189 193 196 198 200)
VMS=(105 107)

exec > >(tee -a "$LOG") 2>&1
echo "===== drain start $(date) dest=$DEST ====="

fail=0

migrate_ct() {
  local id="$1"
  if ! pct status "$id" >/dev/null 2>&1; then
    echo "SKIP $id not on this node"
    return 0
  fi
  echo "===== $(date) pct migrate $id $DEST --restart --timeout 120 ====="
  if pct migrate "$id" "$DEST" --restart --timeout 120; then
    echo "OK $id"
  else
    echo "FAIL $id rc=$?"
    fail=$((fail + 1))
    return 1
  fi
}

echo "===== pause postgres failover ====="
ssh -o BatchMode=yes -o ConnectTimeout=10 root@"$PROX3" "pct exec 150 -- systemctl stop watchdog; pct exec 151 -- systemctl stop keepalived; echo watchdog_and_151_keepalived_stopped"

migrate_ct 131
echo "===== resume postgres failover ====="
ssh -o BatchMode=yes -o ConnectTimeout=10 root@"$PROX1" "pct exec 131 -- systemctl is-active keepalived; pct exec 131 -- ip -4 -br addr | grep -E '10.92.3.(21|23)' || true"
ssh -o BatchMode=yes -o ConnectTimeout=10 root@"$PROX3" "pct exec 151 -- systemctl start keepalived; pct exec 150 -- systemctl start watchdog; echo watchdog_and_151_keepalived_started"

for id in "${CTS[@]}"; do
  migrate_ct "$id" || true
done

for id in "${VMS[@]}"; do
  if ! qm status "$id" >/dev/null 2>&1; then
    echo "SKIP VM $id not on this node"
    continue
  fi
  echo "===== $(date) qm migrate $id $DEST --online ====="
  if qm migrate "$id" "$DEST" --online; then
    echo "OK VM $id"
  else
    echo "FAIL VM $id rc=$?"
    fail=$((fail + 1))
  fi
done

echo "===== drain lxc+vm done $(date) fails=$fail ====="
echo "NOTE: CT190 skipped while vzdump lock held"
pct list
qm list
exit "$fail"
