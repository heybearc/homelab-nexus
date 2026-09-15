#!/usr/bin/env bash
# Mark an app archived in the registry and sync monitoring stack (Prometheus + Watchdog + Alertmanager).
set -euo pipefail

APP_ID="${1:?usage: decommission-app.sh <app_id>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REGISTRY="$ROOT/monitoring/apps-registry.yaml"

python3 - <<PY
import sys
import yaml
from pathlib import Path

app_id = "$APP_ID"
path = Path("$REGISTRY")
data = yaml.safe_load(path.read_text())
found = False
for app in data.get("apps", []):
    if app.get("id") == app_id:
        app["state"] = "archived"
        found = True
        break
if not found:
    print(f"App not found in registry: {app_id}", file=sys.stderr)
    sys.exit(1)
path.write_text(yaml.dump(data, default_flow_style=False, sort_keys=False, allow_unicode=True))
print(f"Set {app_id} -> state: archived")
PY

echo ""
echo "=== Decommission checklist (also see monitoring/apps-registry.yaml) ==="
grep "^  -" "$ROOT/monitoring/apps-registry.yaml" | sed -n '/decommission_checklist:/,\$p' | head -15

echo ""
echo "Running monitoring sync..."
bash "$ROOT/scripts/monitoring/sync-monitoring-stack.sh"

echo ""
echo "Next manual steps:"
echo "  - Uptime Kuma: n8n workflow 'Uptime Kuma · Sync Monitors' or POST CT153:18771/sync"
echo "  - HAProxy / NPM / DNS / Netbox / MCP — see checklist above"
