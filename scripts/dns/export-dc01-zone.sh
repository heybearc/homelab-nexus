#!/usr/bin/env bash
# Export cloudigan.net A records from dc-01 for Technitium import
# Usage:
#   ./export-dc01-zone.sh [output.csv]
#   ./export-dc01-zone.sh /tmp/zone.csv /tmp/zone.txt   # also write RFC1035 zone file
set -euo pipefail

DC01_HOST="${DC01_HOST:-10.92.0.10}"
DC01_USER="${DC01_USER:-cory@cloudigan.com}"
DC01_SSH="${DC01_SSH:-${DC01_USER}@${DC01_HOST}}"
DNS_ZONE="${DNS_ZONE:-cloudigan.net}"
OUT="${1:-/tmp/cloudigan-net-zone.csv}"
ZONE_FILE="${2:-}"

PS='Get-DnsServerResourceRecord -ZoneName '"'"'cloudigan.net'"'"' -RRType A | ForEach-Object { $h = $_.HostName; if ($h -eq '"'"'@'"'"') { $h = '"'"'@'"'"' } ; Write-Output ("$h," + $_.RecordData.IPv4Address.IPAddressToString) }'
B64=$(printf '%s' "$PS" | iconv -f UTF-8 -t UTF-16LE | base64)

echo "hostname,ip" > "$OUT"
ssh -o ConnectTimeout=15 "$DC01_SSH" \
  "powershell.exe -NoProfile -NonInteractive -EncodedCommand ${B64}" \
  | grep -v CLIXML | grep ',' >> "$OUT"

count=$(($(wc -l < "$OUT") - 1))
echo "Exported ${count} A records to $OUT"
head -10 "$OUT"

if [[ -n "$ZONE_FILE" ]]; then
  serial=$(date +%Y%m%d01)
  {
    echo "\$ORIGIN ${DNS_ZONE}."
    echo "@ IN SOA technitium-primary.${DNS_ZONE}. hostmaster.${DNS_ZONE}. ${serial} 3600 900 604800 300"
    echo "@ IN NS technitium-primary.${DNS_ZONE}."
    tail -n +2 "$OUT" | while IFS=, read -r host ip; do
      [[ -z "$host" || -z "$ip" ]] && continue
      if [[ "$host" == "@" || "$host" == "$DNS_ZONE" ]]; then
        echo "@ IN A ${ip}"
      else
        echo "${host%.${DNS_ZONE}} IN A ${ip}"
      fi
    done
  } > "$ZONE_FILE"
  echo "Wrote RFC1035 zone file to $ZONE_FILE ($(wc -l < "$ZONE_FILE") lines)"
fi
