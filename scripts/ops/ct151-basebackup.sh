#!/bin/bash
set -euo pipefail
chmod 600 /root/repl.pass
chmod 755 /usr/local/bin/postgres_exporter
systemctl stop postgresql
rm -rf /var/lib/postgresql/17/main
install -d -o postgres -g postgres -m 700 /var/lib/postgresql/17/main
export PGPASSWORD
PGPASSWORD="$(cat /root/repl.pass)"
sudo -u postgres -E pg_basebackup -h 10.92.3.21 -U replicator -D /var/lib/postgresql/17/main -P -R -X stream -C -S replica_151
unset PGPASSWORD
rm -f /root/repl.pass
chown -R postgres:postgres /var/lib/postgresql/17/main
systemctl start postgresql
sleep 3
systemctl is-active postgresql@17-main
sudo -u postgres psql -tAc "SELECT pg_is_in_recovery();"
