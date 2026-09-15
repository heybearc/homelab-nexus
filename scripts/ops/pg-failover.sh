#!/bin/bash
# Promote CT151 and rely on keepalived VIP 10.92.3.23 for app traffic.
# Called by watchdog when the current primary is unreachable.
set -u

PRIMARY_IP="10.92.3.21"
REPLICA_IP="10.92.3.31"
VIP="10.92.3.23"
LOG="/var/log/pg-failover.log"

log() { echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $*" | tee -a "$LOG"; }

log "=== PostgreSQL failover triggered ==="

IS_REPLICA=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${REPLICA_IP}" \
  "su -c \"psql -tAc 'SELECT pg_is_in_recovery();'\" postgres 2>/dev/null" 2>/dev/null)

if [ "$IS_REPLICA" = "f" ]; then
  log "CT151 is already primary — ensuring VIP is present."
  ssh -o StrictHostKeyChecking=no "root@${REPLICA_IP}" \
    "ip -4 addr show dev eth0 | grep -q ${VIP} || ip addr add ${VIP}/24 dev eth0" >>"$LOG" 2>&1 || true
  exit 0
fi

if [ "$IS_REPLICA" != "t" ]; then
  log "ERROR: Cannot reach CT151 replica at ${REPLICA_IP}"
  exit 1
fi

if ping -c 1 -W 2 "$PRIMARY_IP" >/dev/null 2>&1; then
  if nc -z -w 2 "$PRIMARY_IP" 5432 2>/dev/null; then
    log "ERROR: Primary ${PRIMARY_IP}:5432 still reachable — abort to prevent split-brain"
    exit 1
  fi
fi

log "Promoting CT151 (${REPLICA_IP}) to primary..."
ssh -o StrictHostKeyChecking=no "root@${REPLICA_IP}" \
  "su -c 'pg_ctl promote -D /var/lib/postgresql/17/main' postgres 2>&1" >>"$LOG" 2>&1

sleep 3

IS_PRIMARY=$(ssh -o StrictHostKeyChecking=no "root@${REPLICA_IP}" \
  "su -c \"psql -tAc 'SELECT pg_is_in_recovery();'\" postgres 2>/dev/null" 2>/dev/null)

if [ "$IS_PRIMARY" = "f" ]; then
  log "SUCCESS: CT151 is now primary."
  ssh -o StrictHostKeyChecking=no "root@${REPLICA_IP}" \
    "ip -4 addr show dev eth0 | grep -q ${VIP} || ip addr add ${VIP}/24 dev eth0" >>"$LOG" 2>&1 || true
  if ping -c 1 -W 2 "$VIP" >/dev/null 2>&1; then
    log "VIP ${VIP} is reachable."
  else
    log "WARN: VIP ${VIP} not pingable yet (keepalived may still be taking it)."
  fi
  exit 0
fi

log "ERROR: Promotion failed — CT151 still in recovery mode."
exit 1
