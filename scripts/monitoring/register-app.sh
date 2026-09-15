#!/usr/bin/env bash
# Add a new app stub to monitoring/apps-registry.yaml (then edit IPs/CTIDs and run sync).
set -euo pipefail

APP_ID="${1:?usage: register-app.sh <app_id> [tier: production|infrastructure|media]}"
TIER="${2:-production}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REGISTRY="$ROOT/monitoring/apps-registry.yaml"

BLUE_CTID="${BLUE_CTID:-}"
BLUE_IP="${BLUE_IP:-}"
GREEN_CTID="${GREEN_CTID:-}"
GREEN_IP="${GREEN_IP:-}"
PUBLIC_URL="${PUBLIC_URL:-}"

python3 - <<PY
import yaml
from pathlib import Path

path = Path("$REGISTRY")
data = yaml.safe_load(path.read_text())
if any(a.get("id") == "$APP_ID" for a in data.get("apps", [])):
    raise SystemExit(f"App already in registry: $APP_ID")

entry = {
    "id": "$APP_ID",
    "tier": "$TIER",
    "instances": [],
}
if "$BLUE_CTID" and "$BLUE_IP":
    entry["instances"].append({
        "instance": f"$APP_ID-blue",
        "ctid": int("$BLUE_CTID"),
        "ip": "$BLUE_IP",
    })
if "$GREEN_CTID" and "$GREEN_IP":
    entry["instances"].append({
        "instance": f"$APP_ID-green",
        "ctid": int("$GREEN_CTID"),
        "ip": "$GREEN_IP",
    })
if "$PUBLIC_URL":
    entry["uptime"] = [{"name": f"$APP_ID (Public)", "url": "$PUBLIC_URL"}]

data.setdefault("apps", []).append(entry)
path.write_text(yaml.dump(data, default_flow_style=False, sort_keys=False, allow_unicode=True))
print(f"Added $APP_ID — edit {path} then run sync-monitoring-stack.sh")
PY
