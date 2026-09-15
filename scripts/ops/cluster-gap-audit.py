#!/usr/bin/env python3
"""Live cluster + Postgres collation audit. Run on ansible-control."""
import subprocess
import json
import sys


def ssh(host, cmd, timeout=25):
    r = subprocess.run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=%d" % timeout,
            host,
            cmd,
        ],
        capture_output=True,
        text=True,
    )
    return r.returncode, r.stdout, r.stderr


def section(title):
    print("\n===== %s =====" % title)


section("PG DATABASES name|size|collate|recorded|actual")
rc, out, err = ssh(
    "root@10.92.3.21",
    "sudo -u postgres psql -d postgres -Atc "
    "\"SELECT datname||'|'||pg_size_pretty(pg_database_size(oid))"
    "||'|'||COALESCE(datcollate,'')"
    "||'|'||COALESCE(datcollversion,'')"
    "||'|'||COALESCE(pg_database_collation_actual_version(oid),'') "
    "FROM pg_database WHERE datallowconn ORDER BY datname;\"",
)
print(out)
if err.strip():
    print("STDERR:", err)

section("glibc / OS")
for host, label in (
    ("root@10.92.3.21", "primary"),
    ("root@10.92.3.31", "replica"),
):
    rc, o, e = ssh(host, "ldd --version | head -1; grep PRETTY_NAME /etc/os-release")
    print(label)
    print(o)

section("TEXT INDEX COUNTS")
rc, dbs, _ = ssh(
    "root@10.92.3.21",
    "sudo -u postgres psql -d postgres -Atc "
    "\"SELECT datname FROM pg_database WHERE datallowconn "
    "AND datname NOT IN ('template0') ORDER BY 1;\"",
)
for db in [d.strip() for d in dbs.splitlines() if d.strip()]:
    rc, o, e = ssh(
        "root@10.92.3.21",
        "sudo -u postgres psql -d %s -Atc "
        "\"SELECT count(*) FROM pg_index i "
        "JOIN pg_class c ON c.oid=i.indexrelid "
        "JOIN pg_attribute a ON a.attrelid=i.indexrelid "
        "JOIN pg_type t ON t.oid=a.atttypid "
        "WHERE t.typname IN ('text','varchar','bpchar','name','citext') "
        "AND c.relnamespace::regnamespace::text "
        "NOT IN ('pg_catalog','information_schema');\""
        % db,
    )
    print("%s: %s" % (db, o.strip() or ("ERR " + e[:120])))

section("CT131/151 storage")
for host, ct in (("root@10.92.0.6", "131"), ("root@10.92.0.7", "151")):
    rc, o, e = ssh(
        host,
        "grep -E 'rootfs|hostname|net0' /etc/pve/lxc/%s.conf" % ct,
    )
    print("CT%s:" % ct)
    print(o)

section("HA resources")
rc, o, e = ssh(
    "root@10.92.0.6",
    "echo '--- resources ---'; cat /etc/pve/ha/resources.cfg; "
    "echo '--- groups ---'; cat /etc/pve/ha/groups.cfg; "
    "echo '--- status ---'; ha-manager status",
)
print(o or "(empty)")
if e.strip():
    print("STDERR:", e[:500])

section("vzdump / backup")
rc, o, e = ssh(
    "root@10.92.0.6",
    "echo '--- cron ---'; cat /etc/pve/vzdump.cron; "
    "echo '--- jobs ---'; pvesh get /cluster/backup --output-format json",
)
print(o[:4000] if o else "(empty)")

section("pvesm")
rc, o, e = ssh("root@10.92.0.6", "pvesm status")
print(o)

section("corosync")
rc, o, e = ssh(
    "root@10.92.0.6",
    "pvecm status; echo '--- conf ---'; grep -E 'ring|bindnet|link|name' /etc/pve/corosync.conf",
)
print(o)

section("guest placement")
for host, name in (
    ("root@10.92.0.5", "prox1"),
    ("root@10.92.0.6", "prox2"),
    ("root@10.92.0.7", "prox3"),
):
    rc, o, e = ssh(host, "hostname; echo CTS; pct list; echo VMS; qm list")
    print("--- %s ---" % name)
    print(o)

section("node nics / 10G")
for host, name in (
    ("root@10.92.0.5", "prox1"),
    ("root@10.92.0.6", "prox2"),
    ("root@10.92.0.7", "prox3"),
):
    rc, o, e = ssh(
        host,
        "echo NODE; hostname; "
        "echo IP; ip -br addr; "
        "echo LINK; ip -br link; "
        "echo ETHtool; for i in $(ls /sys/class/net | grep -vE 'lo|veth|fwbr|fwln|fwpr|tap|vmbr'); "
        "do echo -n \"$i \"; ethtool $i 2>/dev/null | grep -E 'Speed|Link detected' | tr '\\n' ' '; echo; done",
    )
    print("--- %s ---" % name)
    print(o)

section("bluegreen pair hosts")
pairs = [
    ("132", "theoshift-green"),
    ("134", "theoshift-blue"),
    ("133", "ldc-blue"),
    ("135", "ldc-green"),
    ("137", "quantshift-blue"),
    ("138", "quantshift-green"),
    ("181", "api-blue"),
    ("182", "api-green"),
    ("193", "chapter-blue"),
    ("194", "chapter-green"),
    ("196", "mail-blue"),
    ("197", "mail-green"),
    ("198", "hhv-blue"),
    ("199", "hhv-green"),
    ("200", "quote-blue"),
    ("201", "quote-green"),
]
for host, name in (
    ("root@10.92.0.5", "prox1"),
    ("root@10.92.0.6", "prox2"),
    ("root@10.92.0.7", "prox3"),
):
    rc, o, e = ssh(host, "pct list | awk '{print $1,$2,$3}'")
    print("--- %s ---" % name)
    for line in o.splitlines():
        vmid = line.split()[0] if line.split() else ""
        if vmid in {p[0] for p in pairs} or vmid in {
            "136",
            "139",
            "131",
            "151",
            "150",
            "128",
            "180",
            "142",
            "192",
        }:
            print(line)

section("dns / redis / npm hosts")
for label, ip in (
    ("technitium", "10.92.3.10"),
    ("adguard", "10.92.3.11"),
    ("technitium2", "10.92.3.203"),
    ("adguard2", "10.92.3.204"),
    ("npm", "10.92.3.12"),
    ("redis", "10.92.3.20"),
    ("monitoring", "10.92.3.2"),
):
    rc, o, e = ssh(
        "root@10.92.0.6",
        "grep -l 'net0.*%s' /etc/pve/lxc/*.conf /etc/pve/qemu-server/*.conf 2>/dev/null; "
        "true" % ip.replace(".", "\\."),
    )
    print("%s %s -> %s" % (label, ip, o.strip() or "not found via conf grep"))
