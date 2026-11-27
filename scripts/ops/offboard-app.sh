#!/usr/bin/env bash
# Remove a homelab app from monitoring, DNS, NetBox, NPM, backups, and Proxmox.
# Public DNS at Wix is a separate confirm step. See .cursor/commands/offboard.md.
#
# Usage:
#   ./scripts/ops/offboard-app.sh <app-id> [--fqdn name]... [--database name] [--apply]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REGISTRY="$ROOT/monitoring/apps-registry.yaml"
APP_MAP="$ROOT/.cloudy-work/_cloudy-ops/context/APP-MAP.md"
PATCH="$ROOT/scripts/ops/patch-cadence.sh"
APPLY=0
APP_ID=""
FQDNS=()
DATABASE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --fqdn) FQDNS+=("$2"); shift 2 ;;
    --database) DATABASE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 <app-id> [--fqdn name]... [--database name] [--apply]"
      exit 0
      ;;
    *)
      if [[ -z "$APP_ID" ]]; then APP_ID="$1"; shift; else echo "Unknown arg: $1" >&2; exit 1; fi
      ;;
  esac
done

[[ -n "$APP_ID" ]] || { echo "Usage: $0 <app-id> [--fqdn name]... [--database name] [--apply]" >&2; exit 1; }

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

eval "$(python3 - "$REGISTRY" "$APP_ID" <<'PY'
import re, sys
path, app_id = sys.argv[1], sys.argv[2]
text = open(path).read().splitlines()
start = next((i for i, line in enumerate(text) if line.strip() == f"- id: {app_id}"), None)
if start is None:
    sys.exit(f"missing registry id {app_id}")
block = []
for line in text[start + 1:]:
    if line.startswith("  - id: ") or line.startswith("decommission_checklist:"):
        break
    block.append(line)
body = "\n".join(block)
ctid = re.search(r"ctid:\s*(\d+)", body)
ip = re.search(r"ip:\s*([0-9.]+)", body)
instance = re.search(r"instance:\s*([^,}\s]+)", body)
names = re.findall(r'name:\s*"([^"]+)"', body)
urls = re.findall(r'url:\s*"([^"]+)"', body)
def sh(value):
    return "'" + str(value).replace("'", "'\\''") + "'"
print(f"CTID={sh(ctid.group(1) if ctid else '')}")
print(f"IP={sh(ip.group(1) if ip else '')}")
print(f"INSTANCE={sh(instance.group(1) if instance else app_id)}")
print("UPTIME_NAMES=(" + " ".join(sh(n) for n in names) + ")")
print("UPTIME_URLS=(" + " ".join(sh(u) for u in urls) + ")")
PY
)"

log() { printf '[offboard] %s\n' "$*"; }
run() {
  if [[ "$APPLY" == "1" ]]; then
    log "RUN $*"
    eval "$1"
  else
    log "DRY $*"
  fi
}

log "app=$APP_ID ct=$CTID ip=$IP instance=$INSTANCE apply=$APPLY"
log "fqdns=${FQDNS[*]:-none} database=${DATABASE:-none}"
log "uptime names=${UPTIME_NAMES[*]:-none}"

if [[ "$APPLY" != "1" ]]; then
  log "Dry run. Re-run with --apply to change the homelab."
  exit 0
fi

find_node() {
  ssh prox "for n in prox1 prox2 prox3; do if ssh \$n pct status $CTID >/dev/null 2>&1; then echo \$n; exit 0; fi; done; exit 1"
}

NODE="$(find_node)"
log "node=$NODE"

ssh prox "ssh $NODE pct shutdown $CTID --timeout 40 || true"
ssh prox "ssh $NODE pct set $CTID --onboot 0"

# Internal DNS (Technitium). Also delete the guest hostname record.
python3 - "$INSTANCE" "${FQDNS[@]}" <<'PY'
import os, sys, json, urllib.parse, urllib.request
names = []
for name in sys.argv[1:]:
    if not name:
        continue
    names.append(name if "." in name else name + ".cloudigan.net")
base = os.environ["TECHNITIUM_URL"].rstrip("/")
token = os.environ.get("TECHNITIUM_API_TOKEN") or open(os.path.expanduser("~/.cache/technitium-token")).read().strip()

def call(path, fields):
    data = urllib.parse.urlencode({"token": token, **fields}).encode()
    req = urllib.request.Request(base + path, data=data)
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.load(resp)

for fqdn in dict.fromkeys(names):
    got = call("/api/zones/records/get", {"domain": fqdn})
    records = got.get("response", {}).get("records", [])
    if not records:
        print(fqdn, "absent")
        continue
    for rec in records:
        rtype = rec.get("type")
        rdata = rec.get("rData") or {}
        fields = {"domain": fqdn, "type": rtype}
        if rtype == "A":
            fields["ipAddress"] = rdata.get("ipAddress", "")
        elif rtype == "CNAME":
            fields["cname"] = rdata.get("cname", "")
        result = call("/api/zones/records/delete", fields)
        print(fqdn, rtype, result.get("status"), result.get("errorMessage", ""))
PY

# NPM proxy host and a certificate used only by that host.
if [[ ${#FQDNS[@]} -gt 0 ]]; then
  fqdn_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${FQDNS[@]}")"
  ssh prox "ssh prox3 pct exec 121 -- python3 -" <<PY
import json, sqlite3, os, glob
want = set(json.loads('''$fqdn_json'''))
db = sqlite3.connect("/data/database.sqlite")
hosts = []
for row in db.execute("SELECT id, domain_names, certificate_id FROM proxy_host"):
    try:
        names = json.loads(row[1] or "[]")
    except Exception:
        names = []
    if want.intersection(names):
        hosts.append(row)
print("hosts", hosts)
for hid, _names, cert in hosts:
    db.execute("DELETE FROM proxy_host WHERE id=?", (hid,))
    for path in glob.glob(f"/data/nginx/proxy_host/{hid}.conf*"):
        os.remove(path)
        print("removed", path)
    if cert:
        others = db.execute("SELECT COUNT(*) FROM proxy_host WHERE certificate_id=?", (cert,)).fetchone()[0]
        if others == 0:
            db.execute("DELETE FROM certificate WHERE id=?", (cert,))
            print("removed cert", cert)
db.commit()
PY
  ssh prox "ssh prox3 pct exec 121 -- /usr/local/openresty/nginx/sbin/nginx -s reload"
fi

# NetBox VM and its address.
python3 - "$INSTANCE" "$IP" <<'PY'
import os, sys, json, urllib.error, urllib.parse, urllib.request
name, ip = sys.argv[1], sys.argv[2]
base = os.environ.get("NETBOX_URL", "http://10.92.3.18").rstrip("/")
token = os.environ["NETBOX_TOKEN"]

def req(method, path, params=None):
    url = base + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, method=method, headers={"Authorization": "Token " + token, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=20) as resp:
            if resp.status == 204 or not resp.length:
                return {}
            return json.load(resp)
    except urllib.error.HTTPError as exc:
        print(method, path, exc.code)
        return {}

if ip:
    ips = req("GET", "/api/ipam/ip-addresses/", {"address": ip}).get("results", [])
    for row in ips:
        req("DELETE", f"/api/ipam/ip-addresses/{row['id']}/")
        print("deleted ip", row["id"], row.get("address"))
vms = req("GET", "/api/virtualization/virtual-machines/", {"name": name}).get("results", [])
for vm in vms:
    vid = vm["id"]
    ifaces = req("GET", "/api/virtualization/interfaces/", {"virtual_machine_id": vid}).get("results", [])
    for iface in ifaces:
        req("DELETE", f"/api/virtualization/interfaces/{iface['id']}/")
    req("DELETE", f"/api/virtualization/virtual-machines/{vid}/")
    print("deleted vm", vid, vm.get("name"))
PY

# Uptime Kuma monitors for this IP, name, or URL.
SPEC="$(IP="$IP" python3 - "${UPTIME_NAMES[@]}" -- "${UPTIME_URLS[@]}" <<'PY'
import json, os, sys
args = sys.argv[1:]
sep = args.index("--")
print(json.dumps({"ip": os.environ["IP"], "names": args[:sep], "urls": args[sep+1:]}))
PY
)"
ssh prox "ssh prox3 pct exec 153 -- python3 -" <<PY
import json, sqlite3, os
spec = json.loads('''$SPEC''')
names = set(spec["names"])
urls = set(spec["urls"])
ip = spec["ip"]
os.system("systemctl stop uptime-kuma")
db = sqlite3.connect("/opt/uptime-kuma-data/kuma.db")
ids = []
for row in db.execute("SELECT id, name, url, hostname FROM monitor"):
    blob = " ".join(str(x or "") for x in row)
    if row[1] in names or row[2] in urls or (ip and ip in blob):
        ids.append(row[0])
print("monitors", ids)
if ids:
    q = ",".join("?" * len(ids))
    db.execute("PRAGMA foreign_keys = OFF")
    for table in ("heartbeat", "stat_minutely", "stat_hourly", "stat_daily", "monitor_tls_info", "monitor_tag", "monitor_notification"):
        try:
            db.execute(f"DELETE FROM {table} WHERE monitor_id IN ({q})", ids)
        except sqlite3.OperationalError:
            pass
    db.execute(f"DELETE FROM monitor WHERE id IN ({q})", ids)
    db.commit()
os.system("systemctl start uptime-kuma")
PY

python3 - "$REGISTRY" "$APP_ID" <<'PY'
from pathlib import Path
import sys
path, app_id = Path(sys.argv[1]), sys.argv[2]
lines = path.read_text().splitlines(keepends=True)
out = []
i = 0
while i < len(lines):
    if lines[i].startswith("  - id: ") and lines[i].strip() == f"- id: {app_id}":
        i += 1
        while i < len(lines) and not lines[i].startswith("  - id: ") and not lines[i].startswith("decommission_checklist:"):
            i += 1
        continue
    out.append(lines[i])
    i += 1
path.write_text("".join(out))
print("registry removed", app_id)
PY

bash "$ROOT/scripts/monitoring/sync-monitoring-stack.sh"

# Drop the dedicated backup job and its archives.
JOB="$(ssh prox ssh prox1 cat /etc/pve/jobs.cfg | python3 -c '
import sys
ctid = sys.argv[1]
job = None
found = ""
for line in sys.stdin:
    if line.startswith("vzdump:"):
        job = line.split()[1].strip()
    elif line.strip().startswith("vmid") and job:
        ids = line.split(None, 1)[1].replace(",", " ").split()
        if ids == [ctid]:
            found = job
print(found)
' "$CTID")"
if [[ -n "$JOB" ]]; then
  ssh prox "ssh prox1 pvesh delete /cluster/backup/$JOB"
  log "removed backup job $JOB"
fi
ssh prox "ssh prox1 'rm -rf /mnt/pve/truenas-backups/dump/vzdump-lxc-$CTID-*'" >/dev/null 2>&1 &
log "archive delete started in the background"

# Snapshots, then the container and its disk.
SNAPS="$(ssh prox ssh "$NODE" pct listsnapshot "$CTID" | python3 -c '
import sys
for line in sys.stdin:
    if "->" not in line or "current" in line:
        continue
    name = line.split("->", 1)[1].split()
    if name:
        print(name[0])
' || true)"
for snap in $SNAPS; do
  ssh prox "ssh $NODE pct delsnapshot $CTID $snap"
done
ssh prox "ssh $NODE pct destroy $CTID --purge"

if [[ -n "$DATABASE" ]]; then
  ssh prox "ssh prox2 pct exec 131 -- bash -s" <<EOF
sudo -u postgres psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DATABASE' AND pid <> pg_backend_pid();"
sudo -u postgres psql -d postgres -c "DROP DATABASE IF EXISTS \"$DATABASE\";"
EOF
fi

python3 - "$PATCH" "$CTID" <<'PY'
from pathlib import Path
import re, sys
path, ctid = Path(sys.argv[1]), sys.argv[2]
out = []
for line in path.read_text().splitlines(keepends=True):
    if re.search(rf"(?:^|[| ]){ctid}(?:[| \"\n]|$)", line):
        line = re.sub(rf"(?:(?<=[| ])|^){ctid}(?=[| \"\n]|$)", "", line)
        line = line.replace("| ", "|").replace(" |", "|")
        line = re.sub(r"  +", " ", line)
    out.append(line)
path.write_text("".join(out))
print("patch cadence cleared", ctid)
PY

python3 - "$APP_MAP" "$INSTANCE" "$CTID" <<'PY'
from pathlib import Path
import sys
path, name, ctid = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
lines = path.read_text().splitlines(keepends=True)
out = []
skip = False
for line in lines:
    if line.startswith("### ") and (name.lower() in line.lower() or f"CT{ctid}" in line or f"CT {ctid}" in line):
        skip = True
        continue
    if skip and line.startswith("### "):
        skip = False
    if not skip:
        out.append(line)
path.write_text("".join(out))
print("app-map cleared")
PY

log "done $APP_ID"
