#!/usr/bin/env bash
# Install Scrypted stream watchdog on CT180 and enable node_exporter textfile metrics.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SSH_CONFIG="${SSH_CONFIG:-$ROOT/.cloudy-work/ssh_config_master.conf}"
SSH=(ssh -F "$SSH_CONFIG")
PROX="${PROX:-prox}"
CTID="${SCRYPTED_CTID:-180}"

"${SSH[@]}" "$PROX" "pct exec $CTID -- mkdir -p /opt/scrypted-watchdog /var/lib/scrypted-watchdog /var/lib/node_exporter/textfile"
scp -F "$SSH_CONFIG" "$ROOT/scripts/scrypted/scrypted-stream-watchdog.sh" "$PROX:/tmp/scrypted-stream-watchdog.sh"
"${SSH[@]}" "$PROX" "pct push $CTID /tmp/scrypted-stream-watchdog.sh /opt/scrypted-watchdog/scrypted-stream-watchdog.sh && pct exec $CTID -- chmod 755 /opt/scrypted-watchdog/scrypted-stream-watchdog.sh"

"${SSH[@]}" "$PROX" "pct exec $CTID -- bash -s" <<'EOS'
set -euo pipefail
cat > /etc/systemd/system/scrypted-stream-watchdog.service <<'UNIT'
[Unit]
Description=Scrypted Baichuan stream watchdog
After=scrypted.service node_exporter.service

[Service]
Type=oneshot
ExecStart=/opt/scrypted-watchdog/scrypted-stream-watchdog.sh
Nice=10
UNIT

cat > /etc/systemd/system/scrypted-stream-watchdog.timer <<'UNIT'
[Unit]
Description=Run Scrypted stream watchdog every 2 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=2min
AccuracySec=15s
Persistent=true

[Install]
WantedBy=timers.target
UNIT

mkdir -p /etc/systemd/system/node_exporter.service.d
cat > /etc/systemd/system/node_exporter.service.d/textfile.conf <<'UNIT'
[Service]
ExecStart=
ExecStart=/usr/local/bin/node_exporter --collector.textfile.directory=/var/lib/node_exporter/textfile
UNIT

systemctl daemon-reload
systemctl restart node_exporter
systemctl enable --now scrypted-stream-watchdog.timer
# first sample (will also restart scrypted if a storm is in progress)
/opt/scrypted-watchdog/scrypted-stream-watchdog.sh || true
systemctl list-timers scrypted-stream-watchdog.timer --no-pager
curl -s http://127.0.0.1:9100/metrics | grep -E '^scrypted_' || true
EOS

echo "Installed stream watchdog on CT${CTID}"
