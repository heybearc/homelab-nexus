#!/usr/bin/env python3
"""Extra Netbox lookups for drifted VMs. Token from env."""
import json
import os
import urllib.parse
import urllib.request

URL = os.environ.get("NETBOX_URL", "http://10.92.3.18").rstrip("/")
TOKEN = os.environ["NETBOX_TOKEN"]


def get(path, params=None):
    q = ("?" + urllib.parse.urlencode(params, doseq=True)) if params else ""
    req = urllib.request.Request(
        URL + path + q,
        headers={"Authorization": "Token " + TOKEN, "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def main():
    for name in (
        "monitor",
        "monitoring-stack",
        "theoshift-blue",
        "theoshift-green",
        "ldctools-blue",
        "nginx-proxy",
        "adguard",
    ):
        data = get("/api/virtualization/virtual-machines/", {"name": name})
        print("\n===", name, "count", data.get("count"), "===")
        for o in data.get("results", []):
            print(
                "id",
                o["id"],
                "primary",
                (o.get("primary_ip4") or {}).get("address"),
                "cf",
                o.get("custom_fields"),
                "comments",
                (o.get("comments") or "")[:180].replace("\n", " | "),
            )
    print("\n=== 10.92.3.24 ===")
    print(json.dumps(get("/api/ipam/ip-addresses/", {"address": "10.92.3.24"}), indent=2)[:1500])
    print("\n=== IP 78 full ===")
    print(json.dumps(get("/api/ipam/ip-addresses/78/"), indent=2)[:2000])
    print("\n=== tags ===")
    tags = get("/extras/tags/", {"limit": 30})
    for t in tags.get("results", []):
        print(t.get("id"), t.get("name"), t.get("slug"))


if __name__ == "__main__":
    main()
