#!/usr/bin/env python3
"""Patch Netbox to match 2026-09-14/15 cluster changes. Token from env."""
import json
import os
import urllib.error
import urllib.request

URL = os.environ.get("NETBOX_URL", "http://10.92.3.18").rstrip("/")
TOKEN = os.environ["NETBOX_TOKEN"]


def req(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    r = urllib.request.Request(
        URL + path,
        data=data,
        method=method,
        headers={
            "Authorization": "Token " + TOKEN,
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(r, timeout=20) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", "replace")
        print("HTTP", e.code, method, path, err[:800])
        raise


def patch(path, body):
    return req("PATCH", path, body)


def post(path, body):
    return req("POST", path, body)


def get(path):
    return req("GET", path)


def main():
    plats = get("/api/dcim/platforms/?slug=debian-12")
    if plats.get("count", 0) == 0:
        debian = post(
            "/api/dcim/platforms/",
            {"name": "Debian 12", "slug": "debian-12"},
        )
        debian_id = debian["id"]
        print("created platform Debian 12 id", debian_id)
    else:
        debian_id = plats["results"][0]["id"]
        print("platform Debian 12 id", debian_id)

    # IP 78 is currently theoshift-blue primary — drop that first or Netbox 400s
    patch(
        "/api/virtualization/virtual-machines/17/",
        {"primary_ip4": None},
    )
    print("cleared theoshift-blue primary_ip4")

    # Postgres RW VIP — was wrongly bound to theoshift-blue / LDC Tools DNS
    ip23 = patch(
        "/api/ipam/ip-addresses/78/",
        {
            "assigned_object_type": None,
            "assigned_object_id": None,
            "role": "vip",
            "status": "active",
            "dns_name": "postgres.cloudigan.net",
            "description": (
                "PostgreSQL RW keepalived VIP (VRID 52) — on writable primary "
                "CT131 10.92.3.21, fails over to CT151 10.92.3.31"
            ),
        },
    )
    print("IP 10.92.3.23", ip23["dns_name"], ip23["role"], ip23["assigned_object"])

    ip21 = patch(
        "/api/ipam/ip-addresses/76/",
        {
            "dns_name": "postgresql.cloudigan.net",
            "description": (
                "PostgreSQL 17 primary CT131 (replication/admin). Apps use VIP 10.92.3.23"
            ),
        },
    )
    print("IP 10.92.3.21", ip21["dns_name"])

    ip31 = patch(
        "/api/ipam/ip-addresses/89/",
        {
            "dns_name": "postgres-replica.cloudigan.net",
            "description": (
                "PostgreSQL 17 streaming replica CT151 Debian 12 — failover target"
            ),
        },
    )
    print("IP 10.92.3.31", ip31["dns_name"])

    ip32 = patch(
        "/api/ipam/ip-addresses/90/",
        {
            "dns_name": "haproxy-standby.cloudigan.net",
            "description": (
                "HAProxy standby CT139 — VRRP BACKUP for VIP 10.92.3.33, node prox2"
            ),
        },
    )
    print("IP 10.92.3.32", ip32["dns_name"])

    ip2 = patch(
        "/api/ipam/ip-addresses/88/",
        {
            "dns_name": "monitoring-stack.cloudigan.net",
            "description": (
                "Monitoring stack CT150 (Prometheus/Grafana/Loki/watchdog) on prox3"
            ),
        },
    )
    print("IP 10.92.3.2", ip2["dns_name"])

    vm131 = patch(
        "/api/virtualization/virtual-machines/15/",
        {
            "platform": debian_id,
            "disk": 100,
            "comments": (
                "Proxmox VMID: 131\n"
                "IP: 10.92.3.21 (node) + VIP 10.92.3.23 (apps)\n"
                "PostgreSQL 17 primary — Debian 12 — prox2\n"
                "Replication to CT151. Apps must use postgres.cloudigan.net / 10.92.3.23\n"
            ),
        },
    )
    print("VM postgresql platform", (vm131.get("platform") or {}).get("name"), "disk", vm131.get("disk"))

    vm151 = patch(
        "/api/virtualization/virtual-machines/24/",
        {
            "platform": debian_id,
            "disk": 100,
            "comments": (
                "Proxmox VMID: 151\n"
                "IP: 10.92.3.31\n"
                "PostgreSQL 17 streaming replica — Debian 12 — prox3\n"
                "Rebuilt 2026-09-14 from truenas-proxmox debian-12 template; slot replica_151\n"
            ),
        },
    )
    print("VM postgres-replica platform", (vm151.get("platform") or {}).get("name"), "disk", vm151.get("disk"))

    vm139 = patch(
        "/api/virtualization/virtual-machines/25/",
        {
            "comments": (
                "Proxmox VMID: 139\n"
                "IP: 10.92.3.32\n"
                "HAProxy standby — VRRP BACKUP (VIP 10.92.3.33) — prox2\n"
                "Migrated prox3→prox2 2026-09-14 so LIVE/STANDBY are not on the same host\n"
            ),
        },
    )
    print("VM haproxy-standby comments ok", vm139["id"])

    vm136 = patch(
        "/api/virtualization/virtual-machines/20/",
        {
            "comments": (
                "Proxmox VMID: 136\n"
                "IP: 10.92.3.26 + holds HAProxy VIP 10.92.3.33\n"
                "HAProxy LIVE — VRRP MASTER — prox3\n"
            ),
        },
    )
    print("VM haproxy comments ok", vm136["id"])

    vm150 = patch(
        "/api/virtualization/virtual-machines/23/",
        {
            "disk": 64,
            "memory": 4096,
            "vcpus": 2,
            "comments": (
                "Proxmox VMID: 150\n"
                "IP: 10.92.3.2\n"
                "Monitoring + pg-failover watchdog — prox3\n"
                "Moved off prox2 2026-09-15 so failover brain is not on the Postgres primary host\n"
                "Netbox name remains monitor (stale VM id 8 also named monitoring-stack is NPM/adguard drift)\n"
            ),
        },
    )
    print("VM monitor id", vm150["id"], "mem", vm150.get("memory"))


if __name__ == "__main__":
    main()
