#!/usr/bin/env bash
# Emergency rollback — restore dc-01 as client DNS
# Usage: ./rollback-dns-cutover.sh
set -euo pipefail

DC01_HOST="${DC01_HOST:-10.92.0.10}"
AG_IP="${ADGUARD_PRIMARY_IP:-10.92.3.11}"

cat <<EOF
=== DNS rollback checklist ===

1. Omada DHCP — set DNS option 6 back to:
     DNS1: ${DC01_HOST}  (dc-01 / AD DNS)
     DNS2: ${AG_IP}      (optional — AdGuard primary)

2. AdGuard primary — revert upstream for ${DNS_ZONE:-cloudigan.net} to dc-01 if changed

3. Re-enable dc-01 writes in provisioning:
     dns-add-record.sh already targets dc-01 by default

4. Verify:
     nslookup n8n.cloudigan.net ${DC01_HOST}

Technitium + standby stack can stay running (no harm) until you debug.

State file (if any): /opt/dns-migration/state.json
EOF
