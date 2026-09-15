#!/usr/bin/env python3
"""Fix leftover Netbox comments that still claim 10.92.3.23 for LDC Tools."""
import json
import os
import urllib.request

URL = os.environ.get("NETBOX_URL", "http://10.92.3.18").rstrip("/")
TOKEN = os.environ["NETBOX_TOKEN"]


def patch(path, body):
    r = urllib.request.Request(
        URL + path,
        data=json.dumps(body).encode(),
        method="PATCH",
        headers={
            "Authorization": "Token " + TOKEN,
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(r, timeout=20) as resp:
        return json.load(resp)


def main():
    vm = patch(
        "/api/virtualization/virtual-machines/29/",
        {
            "status": "offline",
            "comments": (
                "Proxmox VMID: 133 (stopped)\n"
                "Historic IP 10.92.3.23 was reassigned 2026-09-15 to PostgreSQL RW VIP\n"
                "LDC Tools blue is retired/stopped — do not reclaim 10.92.3.23\n"
            ),
        },
    )
    print("ldctools-blue", vm["id"], vm.get("status"))
    vm17 = patch(
        "/api/virtualization/virtual-machines/17/",
        {
            "comments": (
                "Proxmox VMID: 134\n"
                "Live IP: 10.92.3.24 (see IP id 79 / blue-theoshift duplicate)\n"
                "Primary_ip4 cleared 2026-09-15 — 10.92.3.23 is now Postgres RW VIP\n"
            ),
        },
    )
    print("theoshift-blue comments", vm17["id"])


if __name__ == "__main__":
    main()
