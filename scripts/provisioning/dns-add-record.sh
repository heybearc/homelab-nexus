#!/bin/bash
#
# DNS Record Addition Script
# Adds A record to DC-01 (Windows AD DNS)
#

set -euo pipefail

DOMAIN=$1
IP_ADDRESS=$2
DC01_HOST="${DC01_HOST:-10.92.0.10}"
DC01_USER="${DC01_USER:-cory@cloudigan.com}"
DNS_ZONE="${DNS_ZONE:-cloudigan.net}"

if [[ -z "$DOMAIN" ]] || [[ -z "$IP_ADDRESS" ]]; then
    echo "Usage: $0 <domain> <ip_address>"
    exit 1
fi

echo "Adding DNS record: $DOMAIN → $IP_ADDRESS"

# Extract hostname from FQDN (remove .cloudigan.net)
HOSTNAME="${DOMAIN%.${DNS_ZONE}}"

# Add DNS A record via SSH + PowerShell
ssh "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command \"Add-DnsServerResourceRecord -ZoneName '${DNS_ZONE}' -Name '${HOSTNAME}' -A -IPv4Address '${IP_ADDRESS}'\""

if [[ $? -eq 0 ]]; then
    echo "✓ DNS record added: $DOMAIN → $IP_ADDRESS"
    
    # Verify DNS record
    echo "Verifying DNS record..."
    nslookup "$DOMAIN" "$DC01_HOST"
else
    echo "ERROR: Failed to add DNS record"
    exit 1
fi
