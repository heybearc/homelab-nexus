#!/usr/bin/env bash
# Dedupe Uptime Kuma monitors and ensure production stack coverage.
# Runs on CT153 (uptime-kuma). Safe to run repeatedly (idempotent adds).
set -euo pipefail

DB="${UKUMA_DB:-/opt/uptime-kuma-data/kuma.db}"
USER_ID="${UKUMA_USER_ID:-1}"
INTERVAL="${UKUMA_INTERVAL:-60}"

log() { printf '[sync-uptime-kuma] %s\n' "$*"; }
die() { log "ERROR: $*"; exit 1; }

[[ -f "$DB" ]] || die "database not found: $DB"
command -v sqlite3 >/dev/null || die "sqlite3 required"

BACKUP="${DB}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$DB" "$BACKUP"
log "backup -> $BACKUP"

delete_monitor() {
  local id="$1"
  sqlite3 "$DB" <<SQL
DELETE FROM heartbeat WHERE monitor_id = ${id};
DELETE FROM stat_minutely WHERE monitor_id = ${id};
DELETE FROM stat_hourly WHERE monitor_id = ${id};
DELETE FROM stat_daily WHERE monitor_id = ${id};
DELETE FROM monitor_notification WHERE monitor_id = ${id};
DELETE FROM monitor_maintenance WHERE monitor_id = ${id};
DELETE FROM monitor_tag WHERE monitor_id = ${id};
DELETE FROM monitor WHERE id = ${id};
SQL
  log "deleted monitor id=${id}"
}

monitor_exists() {
  local name="$1"
  sqlite3 "$DB" "SELECT COUNT(*) FROM monitor WHERE name = '$name';" | grep -qv '^0$'
}

add_http() {
  local name="$1" url="$2" active="${3:-1}" codes="${4:-[\"200-299\"]}"
  monitor_exists "$name" && return 0
  sqlite3 "$DB" <<SQL
INSERT INTO monitor (name, active, user_id, interval, url, type, weight, accepted_statuscodes_json, method)
VALUES ('${name}', ${active}, ${USER_ID}, ${INTERVAL}, '${url}', 'http', 2000, '${codes}', 'GET');
SQL
  log "added http: ${name}"
}

add_ping() {
  local name="$1" host="$2" active="${3:-1}"
  monitor_exists "$name" && return 0
  sqlite3 "$DB" <<SQL
INSERT INTO monitor (name, active, user_id, interval, hostname, type, weight, packet_size)
VALUES ('${name}', ${active}, ${USER_ID}, ${INTERVAL}, '${host}', 'ping', 2000, 56);
SQL
  log "added ping: ${name}"
}

add_port() {
  local name="$1" host="$2" port="$3" active="${4:-1}"
  monitor_exists "$name" && return 0
  sqlite3 "$DB" <<SQL
INSERT INTO monitor (name, active, user_id, interval, hostname, port, type, weight, accepted_statuscodes_json)
VALUES ('${name}', ${active}, ${USER_ID}, ${INTERVAL}, '${host}', ${port}, 'port', 2000, '["200-299"]');
SQL
  log "added port: ${name}"
}

# --- dedupe: keep lowest id per duplicated name ---
DUPE_IDS=(6 7 8 9 10 11 12 13 14 15)
for id in "${DUPE_IDS[@]}"; do
  if sqlite3 "$DB" "SELECT id FROM monitor WHERE id=${id};" | grep -q .; then
    delete_monitor "$id"
  fi
done

# --- public production URLs ---
add_http "FactorPoint Production (Public)" "https://factorpoint.io" 1 '["200-299","307"]'
add_http "Chapter Hub (Public)" "https://hub.cloudigan.net"
add_http "HHV Blue (Internal Health)" "http://10.92.3.98:3001/health"
add_http "Cloudigan API (Public)" "https://api.cloudigan.net/health"
add_http "Cloudigan Mail (Public)" "https://mail.cloudigan.net/health"
add_http "TIP Generator (Public)" "https://tip.cloudigan.net"
add_http "Jellyfin (Public)" "https://jellyfin.cloudigan.net"
add_http "Authentik (Public)" "https://auth.cloudigan.net"
add_http "Netbox (Public)" "https://netbox.cloudigan.net"
add_http "n8n (Public)" "https://flows.cloudigan.net/healthz"
add_http "Uptime Kuma (Public)" "https://uptime.cloudigan.net"

# --- internal HTTP checks ---
add_http "NPM Admin (Internal)" "http://10.92.3.3:81"
add_http "AdGuard Home (Internal)" "http://10.92.3.11:3000"
add_http "Cloudigan API Blue (Internal)" "http://10.92.3.181:3000/health"
add_http "Loki (Internal)" "http://10.92.3.2:3100/ready"
add_http "Uptime Kuma (Internal)" "http://127.0.0.1:3001"

# --- infrastructure ping ---
add_ping "Proxmox Host" "10.92.0.5"
add_ping "CT139 haproxy-standby" "10.92.3.32"
add_ping "CT151 postgres-replica" "10.92.3.31"
add_ping "CT192 redis-shared" "10.92.3.93"
add_ping "CT121 nginx-proxy" "10.92.3.3"
add_ping "CT140 adguard" "10.92.3.11"
add_ping "CT170 authentik" "10.92.3.75"
add_ping "CT141 netbox" "10.92.3.18"
add_ping "CT188 n8n" "10.92.3.79"
add_ping "CT181 cloudigan-api-blue" "10.92.3.181"
add_ping "CT193 chapter-hub-blue" "10.92.3.96"
add_ping "CT198 hhv-blue" "10.92.3.98"
add_ping "CT190 tip-blue" "10.92.3.91"
add_ping "CT196 cloudigan-mail-blue" "10.92.3.184"
add_ping "CT185 factorpoint-blue" "10.92.3.183"

# --- infrastructure port ---
add_port "Postgres Exporter CT151" "10.92.3.31" 9187
add_port "HAProxy Standby CT139" "10.92.3.32" 80
add_port "Redis Shared CT192" "10.92.3.93" 6379

# --- fix existing monitors (idempotent) ---
sqlite3 "$DB" <<'SQL'
UPDATE monitor SET accepted_statuscodes_json = '["200-299","307"]' WHERE name = 'FactorPoint Production (Public)';
UPDATE monitor SET url = 'https://flows.cloudigan.net/healthz' WHERE name = 'n8n (Public)';
UPDATE monitor SET name = 'HHV Blue (Internal Health)', url = 'http://10.92.3.98:3001/health' WHERE name IN ('HHV (Public)', 'HHV Blue (Internal Health)');
UPDATE monitor SET name = 'Postgres Exporter CT151', hostname = '10.92.3.31', port = 9187 WHERE name = 'PostgreSQL Replica CT151';
UPDATE monitor SET active = 0, description = 'Mgmt VLAN 920 unreachable from app VLAN 923; re-enable after routing restored' WHERE name = 'TrueNAS (Mgmt)';
SQL
log "patched existing monitor configs"

TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM monitor;")
ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM monitor WHERE active=1;")
log "done — ${TOTAL} monitors (${ACTIVE} active)"

if systemctl is-active --quiet uptime-kuma 2>/dev/null; then
  systemctl restart uptime-kuma
  log "restarted uptime-kuma.service"
fi
