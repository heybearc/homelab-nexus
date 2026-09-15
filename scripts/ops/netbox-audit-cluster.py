#!/usr/bin/env python3
"""Read-only Netbox audit for cluster changes. Token from env. No secrets printed."""
import json
import os
import urllib.parse
import urllib.request

URL = os.environ.get("NETBOX_URL", "http://10.92.3.18").rstrip("/")
TOKEN = os.environ["NETBOX_TOKEN"]


def get(path, params=None):
    q = ("?" + urllib.parse.urlencode(params)) if params else ""
    req = urllib.request.Request(
        URL + path + q,
        headers={"Authorization": "Token " + TOKEN, "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def show_ip(addr):
    data = get("/api/ipam/ip-addresses/", {"address": addr})
    print("\n=== IP", addr, "count", data.get("count"), "===")
    for o in data.get("results", []):
        assigned = o.get("assigned_object")
        print(
            "id",
            o.get("id"),
            "status",
            (o.get("status") or {}).get("value"),
            "dns",
            o.get("dns_name"),
            "desc",
            o.get("description"),
            "role",
            (o.get("role") or {}).get("value") if o.get("role") else None,
            "assigned",
            assigned,
        )


def show_vm(name):
    data = get("/api/virtualization/virtual-machines/", {"name": name})
    print("\n=== VM", name, "count", data.get("count"), "===")
    for o in data.get("results", []):
        print(
            json.dumps(
                {
                    "id": o.get("id"),
                    "name": o.get("name"),
                    "status": (o.get("status") or {}).get("value"),
                    "cluster": (o.get("cluster") or {}).get("name"),
                    "device": (o.get("device") or {}).get("name") if o.get("device") else None,
                    "site": (o.get("site") or {}).get("name"),
                    "platform": (o.get("platform") or {}).get("name") if o.get("platform") else None,
                    "primary_ip4": (o.get("primary_ip4") or {}).get("address"),
                    "vcpus": o.get("vcpus"),
                    "memory": o.get("memory"),
                    "disk": o.get("disk"),
                    "comments": (o.get("comments") or "")[:240],
                    "custom_fields": o.get("custom_fields"),
                },
                indent=2,
            )
        )


def main():
    for addr in (
        "10.92.3.21",
        "10.92.3.23",
        "10.92.3.31",
        "10.92.3.2",
        "10.92.3.26",
        "10.92.3.32",
        "10.92.3.33",
    ):
        show_ip(addr)
    for name in (
        "postgresql",
        "postgres-replica",
        "haproxy",
        "haproxy-standby",
        "monitoring-stack",
    ):
        show_vm(name)
    print("\n=== platforms ===")
    plats = get("/api/dcim/platforms/", {"limit": 50})
    for p in plats.get("results", []):
        print(p.get("id"), p.get("name"), p.get("slug"))
    print("\n=== cluster devices ===")
    devs = get("/api/dcim/devices/", {"limit": 50})
    for d in devs.get("results", []):
        name = d.get("name") or ""
        if "prox" in name.lower() or "pve" in name.lower():
            print(d.get("id"), name, (d.get("status") or {}).get("value"))
    print("\n=== ip roles ===")
    roles = get("/api/ipam/roles/", {"limit": 50})
    for r in roles.get("results", []):
        print(r.get("id"), r.get("name"), r.get("slug"))
    print("\n=== prefixes 10.92.3 ===")
    prefs = get("/api/ipam/prefixes/", {"prefix": "10.92.3.0/24"})
    for p in prefs.get("results", []):
        print("prefix id", p.get("id"), p.get("prefix"), p.get("description"))


if __name__ == "__main__":
    main()
