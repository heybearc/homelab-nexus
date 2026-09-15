#!/usr/bin/env python3
"""Discover storage, PG replica, IPs, DNS, backups. Run on ansible-control."""
import subprocess


def ssh(host, cmd, timeout=20):
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


def out(title, host, cmd, timeout=20):
    print("\n===== %s =====" % title)
    rc, o, e = ssh(host, cmd, timeout)
    print(o)
    if e.strip():
        print("STDERR:", e[:800])
    print("RC", rc)


out("storage.cfg", "root@10.92.0.6", "cat /etc/pve/storage.cfg")
out(
    "nfs mount layout",
    "root@10.92.0.6",
    "ls -la /mnt/pve/truenas-proxmox; echo ---; df -h /mnt/pve/truenas-proxmox; echo ---; ls /mnt/pve/truenas-proxmox/template 2>/dev/null; ls /mnt/pve/truenas-backups 2>/dev/null | head",
)
out("ct131 conf", "root@10.92.0.6", "cat /etc/pve/lxc/131.conf")
out("ct151 conf", "root@10.92.0.7", "cat /etc/pve/lxc/151.conf")
out("ct150 conf", "root@10.92.0.6", "cat /etc/pve/lxc/150.conf")
out(
    "pg primary replication + hba",
    "root@10.92.3.21",
    "sudo -u postgres psql -tAc \"SELECT usename, client_addr, state, sync_state FROM pg_stat_replication;\"; "
    "echo '--- slots ---'; "
    "sudo -u postgres psql -tAc \"SELECT slot_name, slot_type, active, restart_lsn FROM pg_replication_slots;\"; "
    "echo '--- hba ---'; "
    "grep -E 'replication|151|10.92.3' /etc/postgresql/17/main/pg_hba.conf; "
    "echo '--- listen ---'; "
    "grep -E 'listen_addresses|wal_level|max_wal_senders|hot_standby' /etc/postgresql/17/main/postgresql.conf",
)
out(
    "pg replica recovery",
    "root@10.92.3.31",
    "ls -la /var/lib/postgresql/17/main/standby.signal /etc/postgresql/17/main/; "
    "echo '--- auto ---'; "
    "cat /var/lib/postgresql/17/main/postgresql.auto.conf 2>/dev/null; "
    "echo '--- pkg ---'; "
    "dpkg -l | grep -E 'postgresql-17|postgres-exporter|keepalived' | awk '{print $2,$3}'; "
    "echo '--- exporter ---'; "
    "systemctl is-active postgresql prometheus-postgres-exporter 2>/dev/null; "
    "ls /etc/default/prometheus-postgres-exporter /etc/postgres_exporter* 2>/dev/null; "
    "echo '--- sshd ---'; "
    "systemctl is-active ssh",
)
out(
    "pg primary pkgs",
    "root@10.92.3.21",
    "dpkg -l | grep -E 'postgresql-17|postgres-exporter|keepalived' | awk '{print $2,$3}'; "
    "echo '--- exporter ---'; "
    "systemctl is-active postgresql prometheus-postgres-exporter 2>/dev/null; "
    "ls /etc/default/prometheus-postgres-exporter 2>/dev/null; "
    "cat /etc/default/prometheus-postgres-exporter 2>/dev/null | grep -v PASSWORD | grep -v password",
)
out(
    "free ips ping",
    "root@10.92.3.90",
    "for i in 20 22 23 24 25 34 35 36 37 38; do "
    "echo -n \"10.92.3.$i \"; ping -c 1 -W 1 10.92.3.$i >/dev/null && echo UP || echo FREE; "
    "done",
)
out(
    "dns records postgres",
    "root@10.92.3.10",
    "which dig; dig +short postgres.cloudigan.net @127.0.0.1; "
    "dig +short postgresql.cloudigan.net @127.0.0.1; "
    "dig +short postgres-replica.cloudigan.net @127.0.0.1; "
    "dig +short postgres-primary.cloudigan.net @127.0.0.1",
)
out(
    "failover script",
    "root@10.92.3.2",
    "sed -n '1,220p' /opt/watchdog/pg-failover.sh; echo '======= webhook ======='; "
    "systemctl cat postgresql-failover-webhook.service | head -40; "
    "ls /usr/local/bin/postgresql-failover* /opt/watchdog/",
)
out(
    "haproxy keepalived sample",
    "root@10.92.3.26",
    "sed -n '1,80p' /etc/keepalived/keepalived.conf",
)
out(
    "adguard / technitium extras",
    "root@10.92.0.6",
    "echo '--- 140 ---'; grep -E 'hostname|net0' /etc/pve/lxc/140.conf; "
    "echo '--- 145 ---'; grep -E 'hostname|net0' /etc/pve/lxc/145.conf; "
    "echo '--- truenas apps dns ---'; true",
)
out(
    "backup job ids",
    "root@10.92.0.6",
    "pvesh get /cluster/backup --output-format json",
    timeout=30,
)
