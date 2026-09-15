#!/usr/bin/env bash
# One-shot: sync cloudigan.net A records from dc-01 → Technitium (lab SoT).
# Safe to re-run (overwrite=true). Does not delete Technitium-only records.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
[[ -f "$ROOT/.env" ]] && set -a && source "$ROOT/.env" && set +a

TECHNITIUM_URL="${TECHNITIUM_URL:-http://10.92.3.10:5380}"
: "${TECHNITIUM_API_TOKEN:?Set TECHNITIUM_API_TOKEN}"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

B64=$(printf '%s' 'Get-DnsServerResourceRecord -ZoneName cloudigan.net -RRType A | ForEach-Object { Write-Output ($_.HostName + "|" + $_.RecordData.IPv4Address.IPAddressToString) }' | iconv -f UTF-8 -t UTF-16LE | base64)
ssh -o BatchMode=yes -o ConnectTimeout=20 dc-01 \
  "powershell.exe -NoProfile -NonInteractive -EncodedCommand ${B64}" \
  | grep '|' | tr -d '\r' > "$TMP"

echo "Exported $(wc -l < "$TMP") A records from dc-01"

python3 - "$TMP" <<'PY'
import json, os, sys, urllib.parse, urllib.request
path = sys.argv[1]
tok = os.environ["TECHNITIUM_API_TOKEN"]
base = os.environ.get("TECHNITIUM_URL", "http://10.92.3.10:5380").rstrip("/")

def post(path, data):
    body = urllib.parse.urlencode({**data, "token": tok}).encode()
    req = urllib.request.Request(f"{base}{path}", data=body, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def get(path):
    url = f"{base}{path}{'&' if '?' in path else '?'}token={urllib.parse.quote(tok)}"
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)

d = get("/api/zones/records/get?domain=cloudigan.net&listZone=true")
tech = set()
for rec in (d.get("response") or {}).get("records") or []:
    if rec.get("type") != "A":
        continue
    name = rec.get("name", "").rstrip(".")
    if name == "cloudigan.net":
        tech.add("@")
    elif name.endswith(".cloudigan.net"):
        tech.add(name[: -len(".cloudigan.net")].lower())

added = 0
for line in open(path):
    line = line.strip()
    if "|" not in line:
        continue
    h, ip = line.split("|", 1)
    h = h.strip().lower()
    ip = ip.strip()
    if h in ("@", "cloudigan.net"):
        h = "@"
    if h in tech:
        continue
    fqdn = "cloudigan.net" if h == "@" else f"{h}.cloudigan.net"
    resp = post("/api/zones/records/add", {
        "domain": fqdn, "type": "A", "ipAddress": ip,
        "ttl": "300", "overwrite": "true", "ptr": "false",
    })
    print(f"{resp.get('status')}: {fqdn} -> {ip} {resp.get('errorMessage','')}")
    if resp.get("status") == "ok":
        added += 1
print(f"done added={added}")
PY

# Resync standby if token present
if [[ -n "${TECHNITIUM_STANDBY_API_TOKEN:-}" ]]; then
  curl -sS "${TECHNITIUM_STANDBY_URL:-http://10.92.3.203:5380}/api/zones/resync?token=${TECHNITIUM_STANDBY_API_TOKEN}&zone=cloudigan.net" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('standby_resync', d.get('status'))"
fi
