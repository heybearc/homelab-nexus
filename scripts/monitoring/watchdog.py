#!/usr/bin/env python3
"""Alertmanager webhook → auto-restart LXC via Proxmox API or PG failover script."""
from __future__ import annotations

import json
import logging
import os
import subprocess
import time
from pathlib import Path

import requests
from flask import Flask, jsonify, request

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("watchdog")
app = Flask(__name__)

CONFIG_PATH = Path(os.environ.get("WATCHDOG_CONFIG", "/opt/watchdog/instances.json"))
FAILOVER_SCRIPTS = {"postgres": "/opt/watchdog/pg-failover.sh"}
ACTIONABLE_ALERTS = {"ContainerDown", "BotContainerDown"}
COOLDOWN_SECONDS = int(os.environ.get("WATCHDOG_COOLDOWN", "300"))

PROXMOX_HOST = os.environ["PROXMOX_HOST"]
TOKEN_ID = os.environ["PROXMOX_TOKEN_ID"]
TOKEN_SECRET = os.environ["PROXMOX_TOKEN_SECRET"]
PROXMOX_NODE = os.environ.get("PROXMOX_NODE", "prox")
PROXMOX_URL = f"https://{PROXMOX_HOST}:8006/api2/json"
HEADERS = {
    "Authorization": f"PVEAPIToken={TOKEN_ID}={TOKEN_SECRET}",
    "Content-Type": "application/json",
}

_last_restart: dict[str, float] = {}


def load_config() -> dict:
    if not CONFIG_PATH.is_file():
        log.error("Missing config: %s", CONFIG_PATH)
        return {"instances": {}, "archived": [], "failover_instances": []}
    return json.loads(CONFIG_PATH.read_text())


def resolve_vmid(labels: dict, cfg: dict) -> tuple[str | None, int | None]:
    instance = labels.get("instance", "")
    if instance in cfg.get("archived", []):
        return instance, None
    instances = cfg.get("instances", {})
    if instance in instances:
        return instance, instances[instance]
    container = labels.get("container", "")
    if container.startswith("ct"):
        try:
            ctid = int(container[2:])
        except ValueError:
            return instance, None
        for name, vmid in instances.items():
            if vmid == ctid:
                return name, ctid
        return instance, ctid
    ctid_label = labels.get("ctid")
    if ctid_label:
        try:
            return instance, int(ctid_label)
        except ValueError:
            pass
    return instance, instances.get(instance)


def get_ct_status(vmid: int) -> str:
    try:
        r = requests.get(
            f"{PROXMOX_URL}/nodes/{PROXMOX_NODE}/lxc/{vmid}/status/current",
            headers=HEADERS,
            verify=False,
            timeout=10,
        )
        return r.json().get("data", {}).get("status", "unknown")
    except Exception as exc:
        log.error("Failed status for VMID %s: %s", vmid, exc)
        return "unknown"


def run_failover(instance: str) -> bool:
    script = FAILOVER_SCRIPTS.get(instance)
    if not script or not os.path.exists(script):
        log.error("No failover script for %s", instance)
        return False
    log.warning("Running failover for %s: %s", instance, script)
    try:
        result = subprocess.run(["bash", script], capture_output=True, text=True, timeout=120)
        log.info("Failover stdout: %s", (result.stdout or "")[-500:])
        if result.returncode != 0:
            log.error("Failover failed: %s", (result.stderr or "")[-300:])
        return result.returncode == 0
    except Exception as exc:
        log.error("Failover exception: %s", exc)
        return False


def restart_ct(vmid: int, instance: str, cfg: dict) -> bool:
    now = time.time()
    last = _last_restart.get(instance, 0)
    if now - last < COOLDOWN_SECONDS:
        log.warning("Cooldown for %s — %ds left", instance, int(COOLDOWN_SECONDS - (now - last)))
        return False

    status = get_ct_status(vmid)
    log.info("VMID %s (%s) status: %s", vmid, instance, status)
    failover_instances = set(cfg.get("failover_instances", []))

    if status == "running":
        if instance in failover_instances:
            log.warning("%s running but failover alert — triggering failover", instance)
            return run_failover(instance)
        log.info("VMID %s already running — no restart", vmid)
        return False

    log.warning("Starting VMID %s (%s)...", vmid, instance)
    try:
        r = requests.post(
            f"{PROXMOX_URL}/nodes/{PROXMOX_NODE}/lxc/{vmid}/status/start",
            headers=HEADERS,
            verify=False,
            timeout=15,
        )
        if r.status_code not in (200, 201):
            log.error("Start failed VMID %s: HTTP %s", vmid, r.status_code)
            if instance in failover_instances:
                return run_failover(instance)
            return False
        _last_restart[instance] = now
        if instance in failover_instances:
            time.sleep(15)
            if get_ct_status(vmid) != "running":
                return run_failover(instance)
        return True
    except Exception as exc:
        log.error("Restart exception VMID %s: %s", vmid, exc)
        if instance in failover_instances:
            return run_failover(instance)
        return False


@app.route("/webhook", methods=["POST"])
def webhook():
    cfg = load_config()
    data = request.get_json(force=True, silent=True) or {}
    alerts = data.get("alerts", [])
    log.info("Received %d alert(s)", len(alerts))
    actions = []
    for alert in alerts:
        if alert.get("status") == "resolved":
            continue
        alertname = alert.get("labels", {}).get("alertname", "")
        if alertname not in ACTIONABLE_ALERTS:
            continue
        labels = alert.get("labels", {})
        instance, vmid = resolve_vmid(labels, cfg)
        if vmid is None:
            log.info("Skip %s — archived or unmapped (%s)", alertname, instance)
            continue
        log.warning("ACTIONABLE: %s instance=%s vmid=%s", alertname, instance, vmid)
        ok = restart_ct(vmid, instance or labels.get("instance", ""), cfg)
        actions.append({"instance": instance, "vmid": vmid, "restarted": ok})
    return jsonify({"status": "ok", "actions": actions}), 200


@app.route("/health", methods=["GET"])
def health():
    cfg = load_config()
    return jsonify({"status": "ok", "mapped_instances": len(cfg.get("instances", {}))}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("WATCHDOG_PORT", "9099")))
