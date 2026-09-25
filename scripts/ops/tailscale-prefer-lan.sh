#!/bin/bash
# Subnet routers must advertise lab prefixes but never install them locally.
# Accepting 10.92.0.0/16 via Tailscale (table 52) blackholes LAN replies and splits corosync.
set -euo pipefail

PREF=5190
LAB=10.92.0.0/16

if command -v tailscale >/dev/null 2>&1; then
  tailscale set --accept-routes=false >/dev/null
fi

while ip rule del pref "$PREF" 2>/dev/null; do
  :
done
ip rule add pref "$PREF" to "$LAB" lookup main
