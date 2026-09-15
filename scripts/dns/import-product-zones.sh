#!/usr/bin/env bash
# Import lab product zones (A → 10.92.3.3) to Technitium + dns-2 secondary.
# Run from Mac: ./scripts/dns/import-product-zones.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZONES=(theoshift.com quantshift.io factorpoint.io helpfulhirschventures.com ldctools.com)

for zone in "${ZONES[@]}"; do
  B64=$(printf '%s' "Get-DnsServerResourceRecord -ZoneName '$zone' -RRType A | ForEach-Object { Write-Output (\$_.HostName + '|' + \$_.RecordData.IPv4Address.IPAddressToString) }" | iconv -f UTF-8 -t UTF-16LE | base64)
  ssh dc-01 "powershell.exe -NoProfile -NonInteractive -EncodedCommand ${B64}" \
    | grep '|' > "/tmp/zone-${zone}.csv"
  scp "/tmp/zone-${zone}.csv" "prox:/tmp/zone-${zone}.csv"
  ssh prox "pct push 145 /tmp/zone-${zone}.csv /tmp/zone-${zone}.csv"
done

TOKEN=$(TECHNITIUM_URL="http://10.92.3.10:5380" "$SCRIPT_DIR/technitium-api.sh" token)
STOKEN=$(TECHNITIUM_URL="http://10.92.3.203:5380" "$SCRIPT_DIR/technitium-api.sh" token)

ssh prox "pct exec 145 -- bash -s" <<REMOTE
set -euo pipefail
TOKEN=${TOKEN}
SERIAL=\$(date +%Y%m%d01)
for zone in ${ZONES[*]}; do
  curl -sS "http://127.0.0.1:5380/api/zones/create?token=\${TOKEN}&zone=\${zone}&type=Primary" >/dev/null || true
  {
    echo "\$ORIGIN \${zone}."
    echo "@ IN SOA technitium-primary.\${zone}. hostmaster.\${zone}. \${SERIAL} 3600 900 604800 300"
    echo "@ IN NS technitium-primary.\${zone}."
    while IFS='|' read -r host ip; do
      [[ -z "\$host" || -z "\$ip" ]] && continue
      [[ "\$host" == "@" ]] && echo "@ IN A \${ip}" || echo "\${host} IN A \${ip}"
    done < "/tmp/zone-\${zone}.csv"
  } > "/tmp/\${zone}.zone"
  curl -sS -X POST "http://127.0.0.1:5380/api/zones/import?token=\${TOKEN}&zone=\${zone}&overwrite=true" \
    -H "Content-Type: text/plain" --data-binary "@/tmp/\${zone}.zone" >/dev/null
  curl -sS "http://127.0.0.1:5380/api/zones/options/set?token=\${TOKEN}" \
    --data-urlencode "zone=\${zone}" \
    --data-urlencode "zoneTransfer=UseSpecifiedNetworkACL" \
    --data-urlencode "zoneTransferNetworkACL=10.92.3.203,10.92.3.200" \
    --data-urlencode "zoneTransferTsigKeyNames=false" \
    --data-urlencode "notify=SpecifiedNameServers" \
    --data-urlencode "notifyNameServers=10.92.3.203" >/dev/null
done
REMOTE

STOKEN=${STOKEN}
for zone in "${ZONES[@]}"; do
  curl -sS "http://10.92.3.203:5380/api/zones/create?token=${STOKEN}" \
    --data-urlencode "zone=${zone}" --data-urlencode "type=Secondary" \
    --data-urlencode "primaryNameServerAddresses=10.92.3.10" \
    --data-urlencode "zoneTransferProtocol=Tcp" >/dev/null 2>&1 || true
  curl -sS "http://10.92.3.203:5380/api/zones/resync?token=${STOKEN}&zone=${zone}" >/dev/null
done

echo "Imported: ${ZONES[*]}"
