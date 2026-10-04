#!/usr/bin/env python3
"""Print running guests and any disk or bind that touches shared storage."""
import glob
import json
import os
import subprocess

raw = subprocess.check_output(
    ["pvesh", "get", "/cluster/resources", "--type", "vm", "--output-format", "json"],
    text=True,
)
vms = json.loads(raw)
running = {
    v["vmid"]: v
    for v in vms
    if v.get("status") == "running"
}

print("VMID NODE TYPE NAME")
for v in sorted(running.values(), key=lambda x: (x.get("node", ""), x.get("vmid", 0))):
    print(f"{v.get('vmid')} {v.get('node')} {v.get('type')} {v.get('name', '')}")

print("---DISKS---")
paths = sorted(
    glob.glob("/etc/pve/nodes/*/lxc/*.conf")
    + glob.glob("/etc/pve/nodes/*/qemu-server/*.conf")
)
for path in paths:
    vmid = int(os.path.basename(path).split(".")[0])
    if vmid not in running:
        continue
    node = path.split("/")[4]
    lines = open(path).read().splitlines()
    hits = []
    for ln in lines:
        s = ln.strip()
        if s.startswith("#"):
            continue
        if s.startswith(("rootfs:", "mp", "scsi", "virtio", "sata", "ide", "hostpci", "dev", "lxc.mount")):
            hits.append(s)
    if not hits:
        continue
    info = running[vmid]
    print(f"{vmid} {node} {info.get('name', '')}")
    for h in hits:
        print(f"  {h}")
