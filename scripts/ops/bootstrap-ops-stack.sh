#!/usr/bin/env bash
# Bootstrap Ops Hub stack on Proxmox LXC CT202 @ 10.92.3.83
# Run from Mac: ./scripts/ops/bootstrap-ops-stack.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SSH_CONFIG="$ROOT/.cloudy-work/ssh_config_master.conf"
OPS_HUB_ROOT="${OPS_HUB_ROOT:-$HOME/Projects/ops-hub}"
OPS_HUB_REPO="${OPS_HUB_REPO:-https://github.com/heybearc/ops-hub.git}"
CTID=202
HOSTNAME=ops-stack
IP=10.92.3.83
GATEWAY=10.92.3.1
BRIDGE=vmbr0923
STORAGE=truenas-proxmox
TEMPLATE=local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst

ssh_prox() { ssh -F "$SSH_CONFIG" prox "$@"; }

echo "=== Ops Stack bootstrap (CT${CTID} ${IP}) ==="

if ! ssh_prox "test -f /etc/pve/lxc/${CTID}.conf"; then
  echo "Creating LXC ${CTID}…"
  ssh_prox "pct create ${CTID} ${TEMPLATE} \
    --hostname ${HOSTNAME} \
    --cores 2 --memory 4096 --swap 512 \
    --rootfs ${STORAGE}:32 \
    --net0 name=eth0,bridge=${BRIDGE},ip=${IP}/24,gw=${GATEWAY} \
    --nameserver 10.92.3.10 \
    --searchdomain cloudigan.net \
    --unprivileged 1 --features nesting=1,keyctl=1 \
    --onboot 1 --start 1"
  echo "Installing SSH key…"
  cat "$HOME/.ssh/homelab_root.pub" | ssh_prox "pct exec ${CTID} -- tee /root/.ssh/authorized_keys"
  ssh_prox "pct exec ${CTID} -- chmod 600 /root/.ssh/authorized_keys"
else
  echo "CT${CTID} exists — starting…"
  ssh_prox "pct start ${CTID} 2>/dev/null || true"
fi

echo "Waiting for SSH…"
for i in $(seq 1 30); do
  if ssh -F "$SSH_CONFIG" -o ConnectTimeout=3 "root@${IP}" "echo ok" 2>/dev/null; then break; fi
  sleep 2
done

echo "Installing base packages…"
ssh -F "$SSH_CONFIG" "root@${IP}" bash -s <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg rsync git docker.io docker-compose-v2
systemctl enable --now docker
if ! command -v node >/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y -qq nodejs
fi
npm install -g pm2
mkdir -p /opt/ops-hub /opt/ops-sync /opt/ntfy
REMOTE

if [[ ! -d "$OPS_HUB_ROOT/ops-hub" || ! -d "$OPS_HUB_ROOT/ops-sync" ]]; then
  echo "Ops Hub source not found at $OPS_HUB_ROOT — cloning ${OPS_HUB_REPO}"
  git clone "$OPS_HUB_REPO" "$OPS_HUB_ROOT"
fi

echo "Syncing ops-hub and ops-sync from $OPS_HUB_ROOT…"
rsync -az --delete --exclude node_modules --exclude .next \
  -e "ssh -F $SSH_CONFIG" \
  "$OPS_HUB_ROOT/ops-hub/" "root@${IP}:/opt/ops-hub/"
rsync -az --delete --exclude node_modules --exclude data \
  -e "ssh -F $SSH_CONFIG" \
  "$OPS_HUB_ROOT/ops-sync/" "root@${IP}:/opt/ops-sync/"
ssh -F "$SSH_CONFIG" "root@${IP}" "mkdir -p /opt/ops-sync/data"

if [[ -f "$ROOT/.env" ]]; then
  echo "Writing /opt/ops-hub/.env…"
  grep -E '^(VIKUNJA|KIMAI|NTFY|OPS_|N8N_OPS|GOOGLE_|M365_)' "$ROOT/.env" > /tmp/ops-hub.env || true
  echo "OPS_SYNC_DATA=/opt/ops-sync/data" >> /tmp/ops-hub.env
  scp -F "$SSH_CONFIG" /tmp/ops-hub.env "root@${IP}:/opt/ops-hub/.env"
  grep -E '^(M365_|GOOGLE_|KIMAI_|VIKUNJA_|NTFY_|OPS_|ANTHROPIC_|OPENAI_|OLLAMA_|ZAMMAD_|PROMETHEUS_)' "$ROOT/.env" > /tmp/ops-sync.env || true
  echo "OPS_SYNC_DATA=/opt/ops-sync/data" >> /tmp/ops-sync.env
  scp -F "$SSH_CONFIG" /tmp/ops-sync.env "root@${IP}:/opt/ops-sync/.env"
fi

echo "Starting ntfy…"
ssh -F "$SSH_CONFIG" "root@${IP}" bash -s <<'REMOTE'
cat > /opt/ntfy/docker-compose.yml <<'YAML'
services:
  ntfy:
    image: binwiederhier/ntfy:latest
    restart: unless-stopped
    command: serve
    environment:
      - NTFY_BASE_URL=https://push.cloudigan.net
      - NTFY_BEHIND_PROXY=true
    volumes:
      - ntfy-cache:/var/cache/ntfy
      - ntfy-data:/etc/ntfy
    ports:
      - "8080:80"
volumes:
  ntfy-cache:
  ntfy-data:
YAML
cd /opt/ntfy && docker compose up -d
REMOTE

echo "Building and starting apps…"
ssh -F "$SSH_CONFIG" "root@${IP}" bash -s <<'REMOTE'
set -euo pipefail
cd /opt/ops-sync && npm install --omit=dev
cd /opt/ops-hub && npm install && npm run build
pm2 delete ops-sync ops-hub 2>/dev/null || true
pm2 start /opt/ops-sync/server.js --name ops-sync
cd /opt/ops-hub && pm2 start npm --name ops-hub -- start
pm2 save
pm2 startup systemd -u root --hp /root | tail -1 | bash || true
REMOTE

echo ""
echo "✓ Ops stack running at http://${IP}:3001 (ops-hub), :3002 (ops-sync), :8080 (ntfy)"
echo "Next: NPM → ops.cloudigan.net → ${IP}:3001, push.cloudigan.net → ${IP}:8080"
echo "      Technitium A records for ops.cloudigan.net and push.cloudigan.net → 10.92.3.3"
echo "      ./scripts/ops/setup-zammad-close-trigger.sh (needs ZAMMAD_API_TOKEN)"
