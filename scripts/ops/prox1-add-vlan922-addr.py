#!/usr/bin/env python3
"""Give prox1 vmbr0922 its storage address. Idempotent."""
from pathlib import Path

PATH = Path("/etc/network/interfaces")
OLD = """iface vmbr0922 inet manual
	bridge-ports ens3f0.922
	bridge-stp off
	bridge-fd 0
	mtu 9000
"""
NEW = """iface vmbr0922 inet static
	address 10.92.2.5/24
	bridge-ports ens3f0.922
	bridge-stp off
	bridge-fd 0
	mtu 9000
# storage VLAN via SX3016F — NFS to TrueNAS 10.92.2.200
"""

text = PATH.read_text()
if "address 10.92.2.5/24" in text and "iface vmbr0922 inet static" in text:
    print("already-set")
elif OLD not in text:
    raise SystemExit("vmbr0922 stanza not in expected form")
else:
    PATH.write_text(text.replace(OLD, NEW, 1))
    print("updated")
