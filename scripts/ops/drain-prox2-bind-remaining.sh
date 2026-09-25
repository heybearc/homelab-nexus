#!/bin/bash
set -u
LOG=/tmp/drain-bind.log
exec > >(tee -a "$LOG") 2>&1
echo "===== bind drain start $(date) ====="
fail=0
run() {
  if /tmp/bind-migrate-ct.sh "$@"; then
    echo "OK bind $1"
  else
    echo "FAIL bind $1 rc=$?"
    fail=$((fail + 1))
  fi
}

run 120 prox1 /mnt/pve/media-pool /mnt/data
run 124 prox1 /mnt/pve/media-pool /mnt/data
run 129 prox1 /mnt/pve/media-pool /mnt/data
run 132 prox1 /mnt/pve/theoshift-uploads /mnt/theoshift-uploads

echo "===== pause postgres failover ====="
ssh -o BatchMode=yes -o ConnectTimeout=10 root@10.92.0.7 "pct exec 150 -- systemctl stop watchdog; pct exec 151 -- systemctl stop keepalived"
run 131 prox1 /mnt/data/backups/jw-scheduler /mnt/backups
echo "===== resume postgres failover ====="
ssh -o BatchMode=yes -o ConnectTimeout=10 root@10.92.0.5 "pct exec 131 -- ip -4 -br addr"
ssh -o BatchMode=yes -o ConnectTimeout=10 root@10.92.0.7 "pct exec 151 -- systemctl start keepalived; pct exec 150 -- systemctl start watchdog"

echo "===== bind drain done $(date) fails=$fail ====="
pct list
exit "$fail"
