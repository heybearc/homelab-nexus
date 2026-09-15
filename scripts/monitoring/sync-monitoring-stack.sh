#!/usr/bin/env bash
# Sync Prometheus, Alertmanager routes, Watchdog map, and alert rules from monitoring/apps-registry.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROX="${PROX:-prox}"
CT_MONITOR="${CT_MONITOR:-150}"
GENERATOR="$ROOT/scripts/monitoring/generate-monitoring-config.py"
REGISTRY="$ROOT/monitoring/apps-registry.yaml"

log() { printf '[sync-monitoring] %s\n' "$*"; }
die() { log "ERROR: $*"; exit 1; }

command -v python3 >/dev/null || die "python3 required"
command -v ssh >/dev/null || die "ssh required"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log "Uploading registry + generator to CT${CT_MONITOR}..."
scp -q "$REGISTRY" "$GENERATOR" "$ROOT/scripts/monitoring/watchdog.py" \
  "$ROOT/monitoring/prometheus-rules/homelab.yml" "$PROX:/tmp/"
ssh "$PROX" "pct push $CT_MONITOR /tmp/apps-registry.yaml /tmp/apps-registry.yaml && \
  pct push $CT_MONITOR /tmp/generate-monitoring-config.py /tmp/generate-monitoring-config.py && \
  pct push $CT_MONITOR /tmp/watchdog.py /opt/watchdog/watchdog.py && \
  pct push $CT_MONITOR /tmp/homelab.yml /etc/prometheus/rules/homelab.yml"

log "Generating Prometheus + Watchdog map on CT${CT_MONITOR}..."
ssh "$PROX" "pct exec $CT_MONITOR -- bash -c '
  set -euo pipefail
  REGISTRY=/tmp/apps-registry.yaml python3 /tmp/generate-monitoring-config.py prometheus > /tmp/prometheus.yml
  REGISTRY=/tmp/apps-registry.yaml python3 /tmp/generate-monitoring-config.py watchdog > /opt/watchdog/instances.json
  cp /tmp/prometheus.yml /etc/prometheus/prometheus.yml
  chown prometheus:prometheus /etc/prometheus/prometheus.yml /etc/prometheus/rules/homelab.yml
'"

log "Fixing Watchdog Proxmox node name (API node: prox1)..."
ssh "$PROX" "pct exec $CT_MONITOR -- bash -c '
  svc=/etc/systemd/system/watchdog.service
  if [[ -f \$svc ]] && grep -qE PROXMOX_NODE=\(pve\|prox\)\$ \$svc; then
    sed -i s/PROXMOX_NODE=pve/PROXMOX_NODE=prox1/ \$svc
    sed -i s/PROXMOX_NODE=prox\$/PROXMOX_NODE=prox1/ \$svc
    systemctl daemon-reload
  fi
'"

log "Patching Alertmanager (watchdog receiver + route)..."
ssh "$PROX" "pct exec $CT_MONITOR -- python3 - <<'PY'
from pathlib import Path
import yaml

path = Path('/etc/alertmanager/alertmanager.yml')
cfg = yaml.safe_load(path.read_text())

receivers = {r['name']: r for r in cfg.get('receivers', [])}
if 'watchdog' not in receivers:
    cfg.setdefault('receivers', []).append({
        'name': 'watchdog',
        'webhook_configs': [{'url': 'http://127.0.0.1:9099/webhook', 'send_resolved': False}],
    })

routes = cfg.setdefault('route', {}).setdefault('routes', [])
if not any(r.get('receiver') == 'watchdog' for r in routes):
    routes.insert(0, {
        'match_re': {'alertname': 'ContainerDown|BotContainerDown'},
        'receiver': 'watchdog',
        'continue': True,
        'group_wait': '10s',
        'group_interval': '1m',
        'repeat_interval': '4h',
    })

path.write_text(yaml.dump(cfg, default_flow_style=False, sort_keys=False))
print('alertmanager patched')
PY"

log "Opening node_exporter port 9100 from 10.92.3.0/24 (UFW hosts)..."
if python3 -c "import yaml" 2>/dev/null; then
  python3 - <<PY
import subprocess, yaml
from pathlib import Path
prox = "$PROX"
reg = yaml.safe_load(Path("$REGISTRY").read_text())
for app in reg.get("apps", []):
    if app.get("state", "active") != "active":
        continue
    for inst in app.get("instances") or []:
        ctid = inst["ctid"]
        subprocess.run(
            ["ssh", prox, "pct", "exec", str(ctid), "--", "bash", "-c",
             "if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q active; then "
             "ufw allow from 10.92.3.0/24 to any port 9100 comment node_exporter >/dev/null 2>&1 || true; fi"],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
PY
else
  log "Skip UFW pass (PyYAML not on Mac — new CTs should use install-monitoring.sh)"
fi

log "Validating and reloading services..."
ssh "$PROX" "pct exec $CT_MONITOR -- bash -c '
  export PATH=/usr/local/bin:\$PATH
  promtool check config /etc/prometheus/prometheus.yml
  promtool check rules /etc/prometheus/rules/homelab.yml
  amtool check-config /etc/alertmanager/alertmanager.yml
  systemctl restart prometheus
  systemctl restart alertmanager
  systemctl restart watchdog
  sleep 3
  curl -sf http://127.0.0.1:9099/health
  curl -sf http://127.0.0.1:9093/-/healthy
'"

log "Summary:"
ssh "$PROX" "pct exec $CT_MONITOR -- python3 -c \"
import json
from pathlib import Path
d=json.loads(Path('/opt/watchdog/instances.json').read_text())
print(f'  Watchdog: {len(d[\\\"instances\\\"])} active, {len(d[\\\"archived\\\"])} archived')
\""
