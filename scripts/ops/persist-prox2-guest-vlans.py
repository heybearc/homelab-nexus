#!/usr/bin/env python3
"""Persist prox2 guest-trunk bridge ports. Run only after the live move checks pass."""
from pathlib import Path

path = Path("/etc/network/interfaces")
text = path.read_text()
orig = text

old_parent = """iface enp4s0f1 inet manual
	mtu 9000
"""
new_parent = """auto enp4s0f1
iface enp4s0f1 inet manual
	mtu 9000
#10G guest trunk, SX3016F
"""
if "auto enp4s0f1\n" not in text:
    if old_parent not in text:
        raise SystemExit("enp4s0f1 stanza missing")
    text = text.replace(old_parent, new_parent, 1)

repls = {
    "	bridge-ports eno1.923\n": "	bridge-ports enp4s0f1.923\n",
    "	bridge-ports eno1.924\n": "	bridge-ports enp4s0f1.924\n",
    "	bridge-ports eno1.925\n": "	bridge-ports enp4s0f1.925\n",
    "iface vmbr0925 inet manual\n	bridge-ports enp4s0f1.925\n	bridge-stp off\n	bridge-fd 0\n":
        "iface vmbr0925 inet manual\n	bridge-ports enp4s0f1.925\n	bridge-stp off\n	bridge-fd 0\n	mtu 1500\n",
    "# VLAN trunk: native 920 on vmbr0; tagged 923-925 on named bridges (922 moved to 10G)\n":
        "# VLAN trunk: native 920 on vmbr0; 923-925 moved to 10G guest trunk\n",
    "# host NFS to TrueNAS 10.92.3.200 — no gateway (mgmt default remains vmbr0)\n":
        "# host VLAN 923 via 10G guest trunk — no gateway (mgmt default remains vmbr0)\n",
}
for old, new in repls.items():
    if old not in text:
        raise SystemExit(f"missing pattern: {old!r}")
    text = text.replace(old, new, 1)

if text == orig:
    raise SystemExit("no change")
path.write_text(text)
print("persisted")
