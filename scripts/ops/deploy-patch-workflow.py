#!/usr/bin/env python3
"""Install the Homelab patch ring workflow on n8n CT188.

Uses N8N_API_TOKEN from the environment. SSH private key path: PATCH_SSH_KEY.
The key is stored in n8n credentials and is not written into this repo.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IDS_FILE = ROOT / "workflows" / "ops" / "workflow-ids.json"
API = os.environ.get("N8N_API_URL", "http://10.92.3.79:5678/api/v1").replace(
    "https://n8n.cloudigan.net/api/v1", "http://10.92.3.79:5678/api/v1"
).rstrip("/")
TOKEN = os.environ.get("N8N_API_TOKEN", "")

COMMANDS = [
    ("Schedule Mon 07:10", "10 7 * * 1", "/usr/local/sbin/patch-cadence.sh check", 0),
    ("Schedule Tue 21:00", "0 21 * * 2", "/usr/local/sbin/patch-cadence.sh ring3", 160),
    ("Schedule Wed 21:00", "0 21 * * 3", "/usr/local/sbin/patch-cadence.sh host prox2", 320),
    ("Schedule Thu 21:00", "0 21 * * 4", "/usr/local/sbin/patch-cadence.sh host prox3", 480),
    ("Schedule Fri 21:00", "0 21 * * 5", "/usr/local/sbin/patch-cadence.sh ring2", 640),
    ("Schedule Sat 02:00", "0 2 * * 6", "/usr/local/sbin/patch-cadence.sh saturday", 800),
    ("Schedule Sun 02:10", "10 2 * * 0", "/usr/local/sbin/patch-cadence.sh patch-standby", 960),
]


def api(method: str, path: str, data: dict | None = None) -> dict:
    url = f"{API}/{path.lstrip('/')}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            "X-N8N-API-KEY": TOKEN,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        raise RuntimeError(f"n8n API {method} {path} failed ({exc.code}): {detail}") from exc


def load_ids() -> dict:
    if IDS_FILE.exists():
        return json.loads(IDS_FILE.read_text())
    return {}


def save_ids(ids: dict) -> None:
    IDS_FILE.write_text(json.dumps(ids, indent=2) + "\n")


def credential_id(private_key: str) -> str:
    creds = api("GET", "credentials")
    rows = creds.get("data", creds) if isinstance(creds, dict) else creds
    for row in rows if isinstance(rows, list) else []:
        if row.get("name") == "prox1 patch-cadence" and row.get("type") == "sshPrivateKey":
            return row["id"]
    created = api(
        "POST",
        "credentials",
        {
            "name": "prox1 patch-cadence",
            "type": "sshPrivateKey",
            "data": {
                "host": "10.92.0.5",
                "port": 22,
                "username": "root",
                "privateKey": private_key,
                "passphrase": "",
            },
        },
    )
    return created["id"]


def build(cred_id: str) -> dict:
    nodes = []
    connections: dict = {}
    for name, cron, command, y in COMMANDS:
        sid = "sched-" + name.split()[1].lower()
        xid = "ssh-" + name.split()[1].lower()
        nodes.append(
            {
                "parameters": {"rule": {"interval": [{"field": "cronExpression", "expression": cron}]}},
                "id": sid,
                "name": name,
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1.2,
                "position": [240, 200 + y],
            }
        )
        nodes.append(
            {
                "parameters": {"authentication": "privateKey", "command": command},
                "id": xid,
                "name": "SSH " + name.split()[1],
                "type": "n8n-nodes-base.ssh",
                "typeVersion": 1,
                "position": [520, 200 + y],
                "credentials": {"sshPrivateKey": {"id": cred_id, "name": "prox1 patch-cadence"}},
            }
        )
        connections[name] = {"main": [[{"node": "SSH " + name.split()[1], "type": "main", "index": 0}]]}
    return {
        "name": "Homelab patch ring",
        "nodes": nodes,
        "connections": connections,
        "settings": {
            "executionOrder": "v1",
            "timezone": "America/New_York",
            "saveManualExecutions": True,
            "executionTimeout": 7200,
        },
    }


def main() -> None:
    if not TOKEN:
        print("N8N_API_TOKEN required", file=sys.stderr)
        sys.exit(1)
    key_path = os.environ.get("PATCH_SSH_KEY", "")
    if not key_path:
        print("PATCH_SSH_KEY required", file=sys.stderr)
        sys.exit(1)
    private_key = Path(key_path).read_text()
    cred_id = credential_id(private_key)
    ids = load_ids()
    payload = build(cred_id)
    wf_id = ids.get("patch_ring")
    if wf_id:
        api("PUT", f"workflows/{wf_id}", payload)
    else:
        created = api("POST", "workflows", payload)
        wf_id = created["id"]
        ids["patch_ring"] = wf_id
        save_ids(ids)
    api("POST", f"workflows/{wf_id}/activate", {})
    print(f"Homelab patch ring ({wf_id}) credential {cred_id}")


if __name__ == "__main__":
    main()
