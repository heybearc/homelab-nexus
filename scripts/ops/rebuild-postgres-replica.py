#!/usr/bin/env python3
"""Rebuild CT151 on Debian 12 from shared template and pg_basebackup from CT131.

Run on ansible-control. Does not print secrets.
"""
import os
import subprocess
import sys
import time


def ssh(host, cmd, timeout=120):
    r = subprocess.run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=15",
            "-o",
            "StrictHostKeyChecking=accept-new",
            host,
            cmd,
        ],
        capture_output=True,
        text=True,
    )
    return r.returncode, r.stdout, r.stderr


def ssh_ok(host, cmd, timeout=120, label=""):
    rc, o, e = ssh(host, cmd, timeout)
    if rc != 0:
        print("FAIL", label or cmd[:80], "rc", rc)
        if o:
            print(o[-1500:])
        if e:
            print(e[-1500:])
        sys.exit(1)
    if o.strip():
        print(o.rstrip())
    return o


def main():
    prox3 = "root@10.92.0.7"
    primary = "root@10.92.3.21"
    work = "/root/151-rebuild"
    ssh_ok("root@10.92.3.90", "mkdir -p %s && chmod 700 %s" % (work, work), label="mkdir work")

    print("== save replica material ==")
    ssh_ok(
        primary,
        "test -x /usr/local/bin/postgres_exporter && echo exporter_ok",
        label="exporter exists",
    )
    rc, o, e = ssh(
        "root@10.92.3.31",
        "python3 -c \""
        "import re;"
        "t=open('/var/lib/postgresql/17/main/postgresql.auto.conf').read();"
        "m=re.search(r\\\"password='([^']+)'\\\", t);"
        "open('/root/repl.pass','w').write(m.group(1) if m else '');"
        "\" && chmod 600 /root/repl.pass && wc -c /root/repl.pass",
    )
    if rc != 0:
        print("could not extract repl password", e)
        sys.exit(1)
    print("saved repl password bytes:", o.strip())

    subprocess.run(
        ["scp", "-o", "BatchMode=yes", "root@10.92.3.31:/root/repl.pass", work + "/repl.pass"],
        check=True,
    )
    subprocess.run(
        [
            "scp",
            "-o",
            "BatchMode=yes",
            "root@10.92.3.31:/root/.ssh/authorized_keys",
            work + "/authorized_keys",
        ],
        check=True,
    )
    subprocess.run(
        [
            "scp",
            "-o",
            "BatchMode=yes",
            "root@10.92.3.21:/usr/local/bin/postgres_exporter",
            work + "/postgres_exporter",
        ],
        check=True,
    )
    ssh("root@10.92.3.31", "rm -f /root/repl.pass")

    print("== shutdown 151 and preserve disk ==")
    ssh_ok(prox3, "pct shutdown 151 --timeout 90 || pct stop 151", timeout=120, label="stop 151")
    ssh_ok(prox3, "cp -a /etc/pve/lxc/151.conf /root/ct151.conf.bak", label="bak conf")
    ssh_ok(
        prox3,
        "mkdir -p /mnt/pve/truenas-proxmox/images/151-pre-debian12 && "
        "if [ -f /mnt/pve/truenas-proxmox/images/151/vm-151-disk-0.raw ]; then "
        "mv /mnt/pve/truenas-proxmox/images/151/vm-151-disk-0.raw "
        "/mnt/pve/truenas-proxmox/images/151-pre-debian12/; fi",
        label="mv disk",
    )
    rc, o, e = ssh(prox3, "pct destroy 151")
    print("destroy 151 rc", rc, o, e)
    ssh(prox3, "rm -f /etc/pve/lxc/151.conf")

    print("== create Debian 12 CT151 ==")
    subprocess.run(
        ["scp", "-o", "BatchMode=yes", work + "/authorized_keys", prox3 + ":/root/151-keys.pub"],
        check=True,
    )
    create = (
        "pct create 151 truenas-proxmox:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst "
        "--hostname postgres-replica --memory 8192 --swap 512 --cores 2 "
        "--unprivileged 1 --features nesting=1,keyctl=1 --onboot 1 "
        "--nameserver 10.92.3.10 --searchdomain cloudigan.net "
        "--net0 name=eth0,bridge=vmbr0923,gw=10.92.3.1,"
        "hwaddr=BC:24:11:35:70:29,ip=10.92.3.31/24,type=veth "
        "--rootfs truenas-proxmox:100 "
        "--ssh-public-keys /root/151-keys.pub --start 1"
    )
    ssh_ok(prox3, create, timeout=180, label="pct create")
    ssh_ok(prox3, "pct set 151 --nameserver '10.92.3.10 10.92.3.203'", label="nameserver")

    print("== wait for SSH ==")
    ssh("root@10.92.3.90", "ssh-keygen -R 10.92.3.31 >/dev/null 2>&1 || true")
    ready = False
    for i in range(30):
        rc, o, e = ssh("root@10.92.3.31", "echo up")
        if rc == 0 and "up" in o:
            ready = True
            break
        time.sleep(3)
    if not ready:
        print("151 ssh not ready")
        sys.exit(1)
    print("ssh ready")

    print("== bootstrap packages ==")
    bootstrap = r"""
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wget gnupg lsb-release curl ca-certificates keepalived sudo
install -d /usr/share/postgresql-common/pgdg
wget -qO /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main' > /etc/apt/sources.list.d/pgdg.list
apt-get update
apt-get install -y postgresql-17 postgresql-client-17 postgresql-17-pgvector
systemctl enable postgresql
"""
    # write bootstrap via python on 151
    py = "open('/tmp/bootstrap.sh','w').write(%r)\n" % bootstrap
    ssh_ok("root@10.92.3.31", "python3 -c %s && bash /tmp/bootstrap.sh" % repr(py), timeout=300, label="bootstrap")

    print("== basebackup ==")
    subprocess.run(
        ["scp", "-o", "BatchMode=yes", work + "/repl.pass", "root@10.92.3.31:/root/repl.pass"],
        check=True,
    )
    subprocess.run(
        [
            "scp",
            "-o",
            "BatchMode=yes",
            work + "/postgres_exporter",
            "root@10.92.3.31:/usr/local/bin/postgres_exporter",
        ],
        check=True,
    )
    backup = r"""
set -e
chmod 600 /root/repl.pass
chmod 755 /usr/local/bin/postgres_exporter
systemctl stop postgresql
rm -rf /var/lib/postgresql/17/main
install -d -o postgres -g postgres -m 700 /var/lib/postgresql/17/main
export PGPASSWORD=$(cat /root/repl.pass)
sudo -u postgres -E pg_basebackup -h 10.92.3.21 -U replicator -D /var/lib/postgresql/17/main -P -R -X stream -C -S replica_151
unset PGPASSWORD
rm -f /root/repl.pass
chown -R postgres:postgres /var/lib/postgresql/17/main
systemctl start postgresql
sleep 3
systemctl is-active postgresql@17-main
sudo -u postgres psql -tAc "SELECT pg_is_in_recovery();"
"""
    py = "open('/tmp/basebackup.sh','w').write(%r)\n" % backup
    ssh_ok("root@10.92.3.31", "python3 -c %s && bash /tmp/basebackup.sh" % repr(py), timeout=300, label="basebackup")

    print("== exporter ==")
    unit = """[Unit]
Description=PostgreSQL Exporter for Prometheus
After=network.target postgresql.service

[Service]
Type=simple
User=postgres
Environment=DATA_SOURCE_NAME=postgresql:///postgres?host=/var/run/postgresql&sslmode=disable
ExecStart=/usr/local/bin/postgres_exporter
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
    py = "open('/etc/systemd/system/postgres_exporter.service','w').write(%r)\n" % unit
    ssh_ok(
        "root@10.92.3.31",
        "python3 -c %s && systemctl daemon-reload && systemctl enable --now postgres_exporter && "
        "systemctl is-active postgres_exporter" % repr(py),
        label="exporter",
    )

    print("== verify streaming from primary ==")
    ssh_ok(
        primary,
        "sudo -u postgres psql -tAc \"SELECT client_addr, state, sync_state, slot_name FROM pg_stat_replication;\"",
        label="replication",
    )
    print("REBUILD_OK")


if __name__ == "__main__":
    os.environ.setdefault("HOME", "/root")
    main()
