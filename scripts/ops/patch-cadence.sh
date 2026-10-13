#!/bin/bash
# Homelab patch cadence. Run on prox1 as root.
#
#   check                 Monday 07:10 — inventory only
#   plan                  what the next windows would do, no changes
#   patch-standby         Sunday 02:10 — apt the HAProxy standby, no traffic switch
#   ring2                 Friday 21:00 — HAProxy, Postgres replica, Vaultwarden backup
#   ring3                 Tuesday 21:00 — one single-container group
#   host prox2|prox3|prox1
#   saturday              Saturday 02:00 — one environment-down target
#   promote <app>         health-gated traffic switch, then patch the old live node
#   postgres-primary      promote the replica, VIP follows, rebuild the old primary as replica
#   postgres-replica
#   haproxy
#   vaultwarden-backup
#   vaultwarden-primary   not on the cron
#   truenas-check         log only
#   truenas-apply         not on the cron; does not reboot TrueNAS from this script
#
# No pending packages: log "no patches available" and do not reboot or migrate.
# /etc/patch-cadence/HOLD skips every mode except check and plan.
set -u

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=40)
LOG_DIR=/var/log/patch-cadence
STATE_DIR=/etc/patch-cadence
NTFY_URL="${NTFY_URL:-https://push.cloudigan.net/homelab-patches}"
TRUENAS="truenas_admin@10.92.0.3"
VIP=10.92.3.33
PINS="100 101 122 128 131"

# app|acl|blue_ct|green_ct|port|health_path
PAIRS=(
  "theoshift|is_theoshift|134|132|3001|/"
  "factorpoint|is_factorpoint|185|187|3001|/"
  "cloudigan-api|is_cloudigan_api|181|182|3000|/health"
  "tip-generator|is_tip|190|191|8000|/health"
  "cloudigan-mail|is_cloudigan_mail|196|197|3020|/health"
  "hhv|is_hhv|198|199|3001|/"
  "chapter-hub|is_chapter_hub|193|194|3001|/"
  "cloudigan-quote-builder|is_cloudigan_quote_builder|200|201|3001|/"
)

# name|ct ids
RING3=(
  "media|120 124 125 127 129 130"
  "business|111 141 153 152 189 184 186 202"
  "identity|170"
  "automation|188"
  "edge|140 145 121"
  "data|192 115 183 119"
  "cameras|180"
  "gpu|122 128"
)

MODE="${1:-check}"
TARGET="${2:-}"
STAMP="$(date +%F)"
mkdir -p "$LOG_DIR" "$STATE_DIR"
LOG="$LOG_DIR/${STAMP}-${MODE}${TARGET:+-$TARGET}.log"

log() { printf '%s\n' "$*" | tee -a "$LOG"; }

ssh_gate() {
  case "${SSH_ORIGINAL_COMMAND:-}" in
    "/usr/local/sbin/patch-cadence.sh check"|\
    "/usr/local/sbin/patch-cadence.sh plan"|\
    "/usr/local/sbin/patch-cadence.sh patch-standby"|\
    "/usr/local/sbin/patch-cadence.sh ring2"|\
    "/usr/local/sbin/patch-cadence.sh ring3"|\
    "/usr/local/sbin/patch-cadence.sh saturday"|\
    "/usr/local/sbin/patch-cadence.sh host prox2"|\
    "/usr/local/sbin/patch-cadence.sh host prox3"|\
    "/usr/local/sbin/patch-cadence.sh host prox1"|\
    "/usr/local/sbin/patch-cadence.sh postgres-replica"|\
    "/usr/local/sbin/patch-cadence.sh postgres-primary"|\
    "/usr/local/sbin/patch-cadence.sh haproxy"|\
    "/usr/local/sbin/patch-cadence.sh vaultwarden-backup"|\
    "/usr/local/sbin/patch-cadence.sh vaultwarden-primary"|\
    "/usr/local/sbin/patch-cadence.sh truenas-check"|\
    "/usr/local/sbin/patch-cadence.sh truenas-apply"|\
    "/usr/local/sbin/patch-cadence.sh promote theoshift"|\
    "/usr/local/sbin/patch-cadence.sh promote factorpoint"|\
    "/usr/local/sbin/patch-cadence.sh promote cloudigan-api"|\
    "/usr/local/sbin/patch-cadence.sh promote tip-generator"|\
    "/usr/local/sbin/patch-cadence.sh promote cloudigan-mail"|\
    "/usr/local/sbin/patch-cadence.sh promote hhv"|\
    "/usr/local/sbin/patch-cadence.sh promote chapter-hub"|\
    "/usr/local/sbin/patch-cadence.sh promote cloudigan-quote-builder")
      exec ${SSH_ORIGINAL_COMMAND}
      ;;
    *)
      echo "denied" >&2
      exit 1
      ;;
  esac
}

if [[ "$MODE" == "--ssh-gate" ]]; then
  ssh_gate
fi

run_node() {
  local node="$1"
  shift
  if [[ "$(hostname -s)" == "$node" ]]; then
    bash -c "$*"
  else
    ssh "${SSH_OPTS[@]}" "$node" "$@"
  fi
}

truenas_ssh() {
  ssh "${SSH_OPTS[@]}" -p 222 "$TRUENAS" "$@"
}

ct_node() {
  pvesh get "/cluster/resources" --type vm --output-format json \
    | python3 -c 'import json,sys
want=int(sys.argv[1])
for r in json.load(sys.stdin):
    if r.get("type")=="lxc" and int(r.get("vmid",-1))==want:
        print(r.get("node",""))
        break
' "$1"
}

ct_ip() {
  local node="$1" id="$2"
  run_node "$node" "pct config $id" | sed -n 's/.*ip=\([0-9.]*\).*/\1/p' | head -1
}

haproxy_target() {
  if run_node prox3 "pct exec 136 -- ip -4 addr" 2>/dev/null | grep -q "$VIP"; then
    echo "prox3 136"
  else
    echo "prox2 139"
  fi
}

live_backend() {
  local acl="$1" where node id
  where="$(haproxy_target)"
  node="${where%% *}"
  id="${where##* }"
  run_node "$node" "pct exec $id -- awk -v acl='$acl' '\$1==\"use_backend\" && \$NF==acl {print \$2; exit}' /etc/haproxy/haproxy.cfg"
}

standby_ct() {
  local acl="$1" blue="$2" green="$3" backend
  backend="$(live_backend "$acl")"
  case "$backend" in
    *green*) echo "$blue" ;;
    *blue*) echo "$green" ;;
    *) echo "" ;;
  esac
}

last_int() {
  printf '%s\n' "$1" | awk '/^[0-9]+$/{n=$1} END{print n+0}'
}

pending_count() {
  local node="$1" id="$2" out
  if ! out="$(run_node "$node" "pct exec $id -- bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq >/tmp/apt-update.err 2>&1; apt-get -s upgrade 2>/dev/null | grep -c ^Inst || true'")"; then
    echo ERR
    return
  fi
  last_int "$out"
}

host_pending() {
  local node="$1" out
  # A failed enterprise repo must not look like zero packages.
  if ! out="$(run_node "$node" "bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq >/tmp/apt-update.err 2>&1 || true; apt-get -s upgrade 2>/dev/null | grep -c ^Inst || true'")"; then
    echo ERR
    return
  fi
  last_int "$out"
}

hold_nvidia() {
  run_node prox1 "bash -c 'dpkg-query -W -f \"\${Package}\\n\" \"nvidia-*\" 2>/dev/null | sed \"s/:amd64//\" | sort -u | xargs -r apt-mark hold'" \
    && log "held nvidia packages on prox1" \
    || log "WARN could not hold nvidia packages"
}

upgrade_ct() {
  local id="$1" node count
  node="$(ct_node "$id")"
  if [[ -z "$node" ]]; then
    log "ABORT CT${id} node unknown"
    return 1
  fi
  count="$(pending_count "$node" "$id")"
  if [[ "$count" == "ERR" ]]; then
    log "ABORT CT${id} pending count failed"
    return 1
  fi
  if [[ "$count" == "0" ]]; then
    log "no patches available CT${id}"
    return 0
  fi
  log "UPGRADE CT${id} on ${node} pending=${count}"
  if ! run_node "$node" "pct exec $id -- bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get upgrade -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold'"; then
    log "ABORT CT${id} apt failed — not rebooted"
    return 1
  fi
  log "REBOOT CT${id}"
  run_node "$node" "pct reboot $id"
  sleep 20
  return 0
}

health_ct() {
  local id="$1" port="$2" path="$3" node ip code
  node="$(ct_node "$id")"
  ip="$(ct_ip "$node" "$id")"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://${ip}:${port}${path}" || true)"
  log "HEALTH CT${id} http://${ip}:${port}${path} -> ${code:-000}"
  [[ "$code" == "200" || "$code" == "302" || "$code" == "307" ]]
}

notify() {
  local summary
  summary="$(tail -n 30 "$LOG")"
  curl -fsS --max-time 10 -H "Title: Homelab ${MODE}${TARGET:+ $TARGET} ${STAMP}" -d "$summary" "$NTFY_URL" >/dev/null 2>&1 || true
}

replication_ok() {
  local out
  out="$(run_node prox1 "pct exec 131 -- su - postgres -c \"psql -Atc \\\"SELECT state || ' ' || COALESCE(EXTRACT(EPOCH FROM replay_lag)::int, 0) FROM pg_stat_replication;\\\"\"" || true)"
  log "REPLICATION ${out:-empty}"
  printf '%s\n' "$out" | awk '
    $1=="streaming" && $2+0<=30 {ok=1}
    END {exit ok?0:1}
  '
}

mode_check() {
  log "CHECK ${STAMP}"
  local line name status node id count
  while read -r line; do
    status="${line%% *}"
    id="$(printf '%s\n' "$line" | awk '{print $2}')"
    name="$(printf '%s\n' "$line" | awk '{print $3}')"
    node="$(printf '%s\n' "$line" | awk '{print $4}')"
    [[ "$status" == "running" ]] || continue
    count="$(pending_count "$node" "$id")"
    log "CT ${id} ${name} ${node} pending=${count:-ERR}"
  done < <(pvesh get /cluster/resources --type vm --output-format json | python3 -c '
import json,sys
rows=[]
for r in json.load(sys.stdin):
    if r.get("type")!="lxc":
        continue
    rows.append("%s %s %s %s" % (r.get("status",""), r.get("vmid",""), r.get("name",""), r.get("node","")))
rows.sort(key=lambda s: int(s.split()[1]))
print("\n".join(rows))
')
  local host
  for host in prox1 prox2 prox3; do
    log "HOST ${host} pending=$(host_pending "$host")"
  done
  mode_truenas_check
  log "PAIRS"
  local spec acl blue green port path stand backend
  for spec in "${PAIRS[@]}"; do
    IFS='|' read -r name acl blue green port path <<<"$spec"
    backend="$(live_backend "$acl")"
    stand="$(standby_ct "$acl" "$blue" "$green")"
    log "PAIR ${name} live_backend=${backend:-unknown} standby=CT${stand:-unknown}"
  done
  if [[ -f "$STATE_DIR/HOLD" ]]; then
    log "HOLD is set"
  fi
  log "RING3 next=$(cat "$STATE_DIR/ring3.next" 2>/dev/null || echo media)"
}

mode_plan() {
  log "PLAN ${STAMP}"
  log "Mon 07:10 check"
  log "Tue 21:00 ring3 next=$(cat "$STATE_DIR/ring3.next" 2>/dev/null || echo media)"
  log "Wed 21:00 host prox2 pending=$(host_pending prox2)"
  log "Thu 21:00 host prox3 pending=$(host_pending prox3)"
  log "Fri 21:00 ring2 haproxy CT136=$(pending_count "$(ct_node 136)" 136) CT139=$(pending_count "$(ct_node 139)" 139) replica=$(pending_count "$(ct_node 151)" 151) vaultwarden-backup=$(pending_count "$(ct_node 172)" 172)"
  log "Sat 02:00 saturday postgres-primary=$(pending_count prox1 131) prox1=$(host_pending prox1)"
  mode_truenas_check
  log "Sun 02:10 patch-standby (no traffic switch)"
  log "Not on the cron: promote, vaultwarden-primary, truenas-apply"
  if [[ -f "$STATE_DIR/HOLD" ]]; then
    log "HOLD is set — apply modes will no-op"
  fi
}

mode_patch_standby() {
  log "PATCH-STANDBY ${STAMP}"
  local spec name acl blue green port path stand backend
  for spec in "${PAIRS[@]}"; do
    IFS='|' read -r name acl blue green port path <<<"$spec"
    backend="$(live_backend "$acl")"
    stand="$(standby_ct "$acl" "$blue" "$green")"
    if [[ -z "$stand" ]]; then
      log "SKIP ${name} could not read HAProxy backend ${backend:-empty}"
      continue
    fi
    log "PAIR ${name} live_backend=${backend} standby=CT${stand}"
    upgrade_ct "$stand" || continue
    health_ct "$stand" "$port" "$path" || log "WARN ${name} standby health failed — traffic stays"
  done
  log "Traffic was not switched. Live nodes were not patched."
}

vip_on() {
  local id="$1" node
  if [[ "$id" == "136" ]]; then node=prox3; else node=prox2; fi
  run_node "$node" "pct exec $id -- ip -4 addr" 2>/dev/null | grep -q "$VIP"
}

wait_vip() {
  local id="$1" i
  for i in $(seq 1 30); do
    vip_on "$id" && return 0
    sleep 1
  done
  return 1
}

haproxy_health() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 -H 'Host: api.cloudigan.net' "http://${VIP}/health" || true)"
  log "HEALTH VIP ${code:-000}"
  [[ "$code" == "200" ]]
}

mode_haproxy() {
  log "HAPROXY"
  local p s primary standby pnode snode pcount scount
  if vip_on 136; then
    primary=136; pnode=prox3; standby=139; snode=prox2
  else
    primary=139; pnode=prox2; standby=136; snode=prox3
  fi
  pcount="$(pending_count "$pnode" "$primary")"
  scount="$(pending_count "$snode" "$standby")"
  log "VIP on CT${primary} primary_pending=${pcount} standby_pending=${scount}"
  if [[ "$pcount" == "0" && "$scount" == "0" ]]; then
    log "no patches available haproxy"
    return 0
  fi
  if [[ "$pcount" == "ERR" || "$scount" == "ERR" ]]; then
    log "ABORT haproxy pending count failed"
    return 1
  fi
  if [[ "$scount" != "0" ]]; then
    upgrade_ct "$standby" || return 1
  else
    log "no patches available CT${standby}"
  fi
  run_node "$snode" "pct exec $standby -- haproxy -c -f /etc/haproxy/haproxy.cfg" || {
    log "ABORT standby haproxy config test failed"
    return 1
  }
  if [[ "$pcount" == "0" ]]; then
    log "no patches available CT${primary}"
    return 0
  fi
  log "MOVE VIP off CT${primary}"
  run_node "$pnode" "pct exec $primary -- systemctl stop keepalived" || return 1
  if ! wait_vip "$standby" || ! haproxy_health; then
    log "ABORT VIP did not move cleanly — starting keepalived on CT${primary}"
    run_node "$pnode" "pct exec $primary -- systemctl start keepalived" || true
    return 1
  fi
  upgrade_ct "$primary" || {
    log "ABORT primary apt failed — VIP left on CT${standby}"
    return 1
  }
  run_node "$pnode" "pct exec $primary -- systemctl start haproxy" || true
  run_node "$pnode" "pct exec $primary -- haproxy -c -f /etc/haproxy/haproxy.cfg" || {
    log "ABORT primary config test failed — VIP left on CT${standby}"
    return 1
  }
  run_node "$pnode" "pct exec $primary -- systemctl start keepalived" || return 1
  if ! wait_vip "$primary" || ! haproxy_health; then
    log "ABORT VIP did not return to CT${primary}"
    return 1
  fi
  log "VIP back on CT${primary}"
}

# CT131 prox1 10.92.3.21 priority 100. CT151 prox3 10.92.3.31 priority 90.
# keepalived adds +20 only while check-pg-primary.sh succeeds, so the VIP
# stays on a writable primary. Stop the old primary before promote so 90+20
# beats a failed check at priority 100.
PG_DID_WORK=0

pg_sql() {
  local node="$1" id="$2" sql="$3" out
  out="$(run_node "$node" "pct exec $id -- su - postgres -c \"psql -Atc \\\"$sql\\\"\"" || true)"
  printf '%s\n' "$out"
}

pg_recovery() {
  pg_sql "$1" "$2" "SELECT pg_is_in_recovery();" | awk '/^[tf]$/{v=$1} END{print v}'
}

pg_identify() {
  local a b
  a="$(pg_recovery prox1 131)"
  b="$(pg_recovery prox3 151)"
  if [[ "$a" == "f" && "$b" == "t" ]]; then
    PG_P_NODE=prox1; PG_P_ID=131; PG_P_IP=10.92.3.21
    PG_R_NODE=prox3; PG_R_ID=151; PG_R_IP=10.92.3.31
  elif [[ "$a" == "t" && "$b" == "f" ]]; then
    PG_P_NODE=prox3; PG_P_ID=151; PG_P_IP=10.92.3.31
    PG_R_NODE=prox1; PG_R_ID=131; PG_R_IP=10.92.3.21
  else
    log "ABORT postgres roles unclear CT131=${a:-empty} CT151=${b:-empty}"
    return 1
  fi
  log "POSTGRES primary=CT${PG_P_ID} ${PG_P_IP} replica=CT${PG_R_ID} ${PG_R_IP}"
}

pg_caught_up() {
  local line
  line="$(pg_sql "$PG_P_NODE" "$PG_P_ID" "SELECT state || ' ' || COALESCE(EXTRACT(EPOCH FROM replay_lag)::int::text, '0') FROM pg_stat_replication WHERE client_addr='${PG_R_IP}';" | awk '/^(streaming|catchup|startup|stopping|backup) /{print; exit}')"
  log "REPLICATION ${line:-none}"
  [[ "$line" == streaming\ * ]] || return 1
  [[ "${line##* }" -le 5 ]]
}

pg_has_vip() {
  local node="$1" id="$2"
  run_node "$node" "pct exec $id -- ip -4 addr" 2>/dev/null | grep -q "10.92.3.23"
}

pg_clear_readonly() {
  pg_sql "$PG_P_NODE" "$PG_P_ID" "ALTER SYSTEM RESET default_transaction_read_only; SELECT pg_reload_conf();" >/dev/null || true
}

pg_stop() {
  run_node "$1" "pct exec $2 -- systemctl stop postgresql"
}

pg_start() {
  run_node "$1" "pct exec $2 -- systemctl start postgresql"
}

pg_repl_pass() {
  local node="$1" id="$2"
  run_node "$node" "pct exec $id -- python3 -c 'import pathlib,re; p=pathlib.Path(\"/var/lib/postgresql/17/main/postgresql.auto.conf\"); t=p.read_text() if p.exists() else \"\"; m=re.search(r\"password=(\\S+)\", t); print(m.group(1) if m else \"\", end=\"\")'"
}

pg_drop_slot() {
  local slot="$1" row active
  row="$(pg_sql "$PG_P_NODE" "$PG_P_ID" "SELECT active FROM pg_replication_slots WHERE slot_name='${slot}';" | awk '/^[tf]$/{print; exit}')"
  if [[ -z "$row" ]]; then
    return 0
  fi
  if [[ "$row" == "t" ]]; then
    log "ABORT slot ${slot} is still active"
    return 1
  fi
  pg_sql "$PG_P_NODE" "$PG_P_ID" "SELECT pg_drop_replication_slot('${slot}');" >/dev/null
  log "DROPPED slot ${slot}"
}

pg_rebuild_replica() {
  local slot="replica_${PG_R_ID}" pass
  log "REBUILD replica CT${PG_R_ID} from ${PG_P_IP} slot ${slot}"
  pass="${PG_REPL_PASS:-}"
  if [[ -z "$pass" ]]; then
    pass="$(pg_repl_pass "$PG_R_NODE" "$PG_R_ID")"
  fi
  if [[ -z "$pass" ]]; then
    log "ABORT replicator password missing on CT${PG_R_ID}"
    return 1
  fi
  pg_stop "$PG_R_NODE" "$PG_R_ID" || return 1
  pg_drop_slot "$slot" || return 1
  printf '%s' "$pass" | run_node "$PG_R_NODE" "pct exec $PG_R_ID -- tee /root/repl.pass >/dev/null" || return 1
  unset pass
  unset PG_REPL_PASS
  if ! run_node "$PG_R_NODE" "pct exec $PG_R_ID -- bash -c 'set -e; chmod 600 /root/repl.pass; rm -rf /var/lib/postgresql/17/main; install -d -o postgres -g postgres -m 700 /var/lib/postgresql/17/main; PGPASSWORD=\$(cat /root/repl.pass); export PGPASSWORD; sudo -u postgres -E pg_basebackup -h ${PG_P_IP} -U replicator -D /var/lib/postgresql/17/main -R -X stream -C -S ${slot}; unset PGPASSWORD; python3 - <<\"PY\"
import pathlib
pw = pathlib.Path(\"/root/repl.pass\").read_text().strip()
p = pathlib.Path(\"/var/lib/postgresql/17/main/postgresql.auto.conf\")
t = p.read_text() if p.exists() else \"\"
if pw and \"password=\" not in t and \"host=\" in t:
    p.write_text(t.replace(\"host=\", \"password=%s host=\" % pw, 1))
PY
rm -f /root/repl.pass'"; then
    run_node "$PG_R_NODE" "pct exec $PG_R_ID -- rm -f /root/repl.pass" || true
    log "ABORT basebackup onto CT${PG_R_ID} failed"
    return 1
  fi
  pg_start "$PG_R_NODE" "$PG_R_ID" || return 1
  local i
  for i in $(seq 1 30); do
    pg_caught_up && return 0
    sleep 2
  done
  log "ABORT CT${PG_R_ID} did not stream after rebuild"
  return 1
}

pg_switch() {
  local n old_p_node old_p_id
  log "SWITCH promote CT${PG_R_ID} then rebuild CT${PG_P_ID} as replica"
  PG_REPL_PASS="$(pg_repl_pass "$PG_R_NODE" "$PG_R_ID")"
  if [[ -z "$PG_REPL_PASS" ]]; then
    log "ABORT replicator password missing on CT${PG_R_ID}"
    return 1
  fi
  pg_sql "$PG_P_NODE" "$PG_P_ID" "ALTER SYSTEM SET default_transaction_read_only = on; SELECT pg_reload_conf(); CHECKPOINT;" >/dev/null
  local i
  for i in $(seq 1 30); do
    pg_caught_up && break
    sleep 2
  done
  if ! pg_caught_up; then
    log "ABORT replica not caught up — read-only cleared, not promoted"
    pg_clear_readonly
    unset PG_REPL_PASS
    return 1
  fi
  old_p_node="$PG_P_NODE"
  old_p_id="$PG_P_ID"
  pg_stop "$PG_P_NODE" "$PG_P_ID" || return 1
  if run_node "$PG_P_NODE" "pct exec $PG_P_ID -- pg_isready -q"; then
    log "ABORT CT${PG_P_ID} still accepts connections"
    pg_start "$PG_P_NODE" "$PG_P_ID" || true
    pg_clear_readonly
    unset PG_REPL_PASS
    return 1
  fi
  if ! pg_sql "$PG_R_NODE" "$PG_R_ID" "SELECT pg_promote(true, 60);" | awk '/^ERROR/{found=1} END{exit found?0:1}'; then
    :
  else
    log "ABORT pg_promote failed"
    pg_start "$old_p_node" "$old_p_id" || true
    pg_clear_readonly
    unset PG_REPL_PASS
    return 1
  fi
  local rec
  rec="$(pg_recovery "$PG_R_NODE" "$PG_R_ID")"
  if [[ "$rec" != "f" ]]; then
    log "ABORT CT${PG_R_ID} still in recovery — starting old primary"
    pg_start "$old_p_node" "$old_p_id" || true
    pg_clear_readonly
    unset PG_REPL_PASS
    return 1
  fi
  pg_sql "$PG_R_NODE" "$PG_R_ID" "ALTER SYSTEM RESET primary_conninfo; ALTER SYSTEM RESET primary_slot_name; SELECT pg_reload_conf();" >/dev/null || true
  local moved=0
  for i in $(seq 1 20); do
    if pg_has_vip "$PG_R_NODE" "$PG_R_ID"; then
      moved=1
      break
    fi
    sleep 2
  done
  if [[ "$moved" != "1" ]]; then
    log "ABORT VIP 10.92.3.23 did not move to CT${PG_R_ID}. Old primary stays stopped."
    unset PG_REPL_PASS
    return 1
  fi
  log "VIP 10.92.3.23 is on CT${PG_R_ID}"
  # Old primary is stopped. Rebuild it from the promoted node before it can boot the old data directory.
  PG_R_NODE="$old_p_node"
  PG_R_ID="$old_p_id"
  if [[ "$PG_R_ID" == "131" ]]; then
    PG_R_IP=10.92.3.21
    PG_P_NODE=prox3; PG_P_ID=151; PG_P_IP=10.92.3.31
  else
    PG_R_IP=10.92.3.31
    PG_P_NODE=prox1; PG_P_ID=131; PG_P_IP=10.92.3.21
  fi
  pg_rebuild_replica || return 1
  n="$(pending_count "$PG_R_NODE" "$PG_R_ID")"
  if [[ "$n" != "0" && "$n" != "ERR" ]]; then
    upgrade_ct "$PG_R_ID" || log "WARN CT${PG_R_ID} apt failed after it became the replica"
    pg_caught_up || log "WARN replica not streaming after apt"
  else
    log "no patches available CT${PG_R_ID}"
  fi
  log "SWITCH done primary=CT${PG_P_ID} replica=CT${PG_R_ID}"
}

mode_postgres_replica() {
  pg_identify || return 1
  local n
  n="$(pending_count "$PG_R_NODE" "$PG_R_ID")"
  if [[ "$n" == "0" ]]; then
    log "no patches available CT${PG_R_ID}"
    return 0
  fi
  if [[ "$n" == "ERR" ]]; then
    log "ABORT CT${PG_R_ID} pending count failed"
    return 1
  fi
  upgrade_ct "$PG_R_ID" || return 1
  sleep 15
  pg_caught_up || { log "ABORT replica did not catch up"; return 1; }
}

mode_postgres_primary() {
  PG_DID_WORK=0
  pg_identify || return 1
  local repl_line
  repl_line="$(pg_sql "$PG_P_NODE" "$PG_P_ID" "SELECT state FROM pg_stat_replication WHERE client_addr='${PG_R_IP}';" | awk '/^(streaming|catchup|startup|stopping|backup)$/{print; exit}')"
  if [[ "$repl_line" != "streaming" ]]; then
    log "replica is not streaming — rebuilding it before any promote"
    pg_rebuild_replica || return 1
    PG_DID_WORK=1
    pg_identify || return 1
  fi
  if ! pg_caught_up; then
    log "ABORT replica is streaming but not caught up — not promoted"
    return 1
  fi
  local n
  n="$(pending_count "$PG_P_NODE" "$PG_P_ID")"
  if [[ "$n" == "ERR" ]]; then
    log "ABORT primary pending count failed"
    return 1
  fi
  if [[ "$n" == "0" ]]; then
    log "no patches available CT${PG_P_ID}"
    return 0
  fi
  pg_switch || return 1
  PG_DID_WORK=1
}

mode_postgres_plan() {
  pg_identify || return 1
  pg_caught_up || true
  local pass
  pass="$(pg_repl_pass "$PG_R_NODE" "$PG_R_ID")"
  if [[ -n "$pass" ]]; then
    log "replicator password present"
  else
    log "ABORT replicator password missing"
  fi
  unset pass
  if pg_has_vip "$PG_P_NODE" "$PG_P_ID"; then
    log "VIP 10.92.3.23 on primary CT${PG_P_ID}"
  else
    log "VIP 10.92.3.23 is not on primary CT${PG_P_ID}"
  fi
  log "postgres-plan makes no changes"
}

mode_vaultwarden() {
  local id="$1" label="$2" n
  log "VAULTWARDEN ${label} CT${id}"
  n="$(pending_count "$(ct_node "$id")" "$id")"
  if [[ "$n" == "0" ]]; then
    log "no patches available CT${id}"
    return 0
  fi
  upgrade_ct "$id" || return 1
  local node ip code
  node="$(ct_node "$id")"
  ip="$(ct_ip "$node" "$id")"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://${ip}/" || true)"
  log "HEALTH CT${id} http://${ip}/ -> ${code:-000}"
}

mode_ring2() {
  mode_haproxy || return 1
  mode_postgres_replica || return 1
  mode_vaultwarden 172 backup
}

dns_lookup() {
  local server="$1"
  nslookup google.com "$server" >/dev/null 2>&1
}

dns_standby() {
  log "DNS STANDBY"
  if ! truenas_ssh true; then
    log "SKIP dns-standby ssh to TrueNAS failed"
    return 0
  fi
  truenas_ssh "cat > /home/truenas_admin/dns-standby-update.py" < /usr/local/sbin/dns-standby-update.py || {
    log "SKIP dns-standby upload failed"
    return 0
  }
  local created id
  created="$(truenas_ssh "midclt call cronjob.create '{\"command\": \"python3 /home/truenas_admin/dns-standby-update.py\", \"description\": \"dns-standby-update\", \"enabled\": false, \"user\": \"root\", \"schedule\": {\"minute\": \"0\", \"hour\": \"0\", \"dom\": \"1\", \"month\": \"1\", \"dow\": \"1\"}, \"stdout\": false, \"stderr\": false}'")" || {
    log "SKIP dns-standby cron create failed"
    return 0
  }
  id="$(printf '%s\n' "$created" | python3 -c 'import json,sys,re
raw=sys.stdin.read().strip()
try:
    d=json.loads(raw)
    print(d.get("id",""))
except Exception:
    m=re.findall(r"\b\d+\b", raw)
    print(m[-1] if m else "")
')"
  if [[ -z "$id" || "$id" == "0" ]]; then
    log "SKIP dns-standby no cron id"
    return 0
  fi
  truenas_ssh "midclt call cronjob.run $id true" >/dev/null || true
  local i line
  for i in $(seq 1 60); do
    line="$(truenas_ssh "tail -n 1 /home/truenas_admin/standby-update.txt" 2>/dev/null || true)"
    [[ "$line" == "DONE" ]] && break
    sleep 10
  done
  truenas_ssh "midclt call cronjob.delete $id" >/dev/null || log "WARN dns-standby cron $id not deleted"
  truenas_ssh "cat /home/truenas_admin/standby-update.txt" | while read -r line; do
    log "DNS $line"
  done
}

dns_verify() {
  local ok=0
  dns_lookup 10.92.3.10 && log "DNS technitium primary ok" || { log "ABORT technitium primary lookup failed"; ok=1; }
  dns_lookup 10.92.3.11 && log "DNS adguard primary ok" || { log "ABORT adguard primary lookup failed"; ok=1; }
  dns_lookup 10.92.3.203 && log "DNS technitium standby ok" || log "WARN technitium standby lookup failed"
  dns_lookup 10.92.3.204 && log "DNS adguard standby ok" || log "WARN adguard standby lookup failed"
  return "$ok"
}

mode_edge() {
  dns_standby
  upgrade_ct 140 || return 1
  upgrade_ct 145 || return 1
  dns_verify || return 1
  upgrade_ct 121 || return 1
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://10.92.3.3/ || true)"
  log "HEALTH NPM http://10.92.3.3/ -> ${code:-000}"
}

mode_ring3() {
  local next spec name ids i
  next="$(cat "$STATE_DIR/ring3.next" 2>/dev/null || echo media)"
  log "RING3 ${next}"
  for i in "${!RING3[@]}"; do
    IFS='|' read -r name ids <<<"${RING3[$i]}"
    if [[ "$name" == "$next" ]]; then
      if [[ "$name" == "edge" ]]; then
        mode_edge || log "ABORT edge group"
      else
        local id
        for id in $ids; do
          upgrade_ct "$id" || log "ABORT CT${id} left for the next cycle"
        done
      fi
      local nxt="${RING3[$(( (i + 1) % ${#RING3[@]} ))]}"
      nxt="${nxt%%|*}"
      printf '%s\n' "$nxt" > "$STATE_DIR/ring3.next"
      log "RING3 next=${nxt}"
      return 0
    fi
  done
  log "ABORT unknown ring3 group ${next}"
  printf '%s\n' media > "$STATE_DIR/ring3.next"
  return 1
}

evacuated_file() { echo "$STATE_DIR/evacuated-$1"; }

is_pinned() {
  local id="$1" pin
  for pin in $PINS; do
    [[ "$pin" == "$id" ]] && return 0
  done
  ha-manager status 2>/dev/null | grep -q "^service ct:${id} " && return 0
  return 1
}

migrate_away() {
  local node="$1" dest="$2" id file
  file="$(evacuated_file "$node")"
  : > "$file"
  while read -r id; do
    [[ -n "$id" ]] || continue
    if is_pinned "$id"; then
      log "PIN CT${id} stays on ${node}"
      continue
    fi
    log "MIGRATE CT${id} ${node} -> ${dest}"
    if ! run_node "$node" "pct migrate $id $dest --online"; then
      log "ABORT migrate CT${id} failed"
      return 1
    fi
    echo "$id" >> "$file"
  done < <(run_node "$node" "pct list" | awk 'NR>1 && $2=="running" {print $1}')
}

migrate_back() {
  local origin="$1" id cur
  local file
  file="$(evacuated_file "$origin")"
  [[ -f "$file" ]] || return 0
  while read -r id; do
    [[ -n "$id" ]] || continue
    cur="$(ct_node "$id")"
    log "MIGRATE CT${id} ${cur} -> ${origin}"
    run_node "$cur" "pct migrate $id $origin --online" || {
      log "ABORT could not return CT${id} to ${origin}"
      return 1
    }
  done < "$file"
  rm -f "$file"
}

wait_node() {
  local node="$1" i
  for i in $(seq 1 60); do
    ssh "${SSH_OPTS[@]}" -o ConnectTimeout=5 "$node" true 2>/dev/null && break
    sleep 10
  done
  ssh "${SSH_OPTS[@]}" "$node" true || return 1
  local j
  for j in $(seq 1 18); do
    run_node "$node" "pct list" >/dev/null 2>&1 && return 0
    sleep 10
  done
  return 1
}

verify_host_net() {
  local node="$1"
  run_node "$node" "ip -4 addr show vmbr0923" | grep -q "10.92.3." || log "WARN ${node} vmbr0923 has no 10.92.3 address"
  run_node "$node" "ping -c 1 -W 3 10.92.2.200" >/dev/null || {
    log "ABORT ${node} cannot reach storage 10.92.2.200"
    return 1
  }
  log "NET ${node} storage ok"
}

mode_host() {
  local node="$1" dest pending file
  case "$node" in
    prox2) dest=prox3 ;;
    prox3) dest=prox2 ;;
    prox1) dest=prox2 ;;
    *) log "ABORT unknown host ${node}"; return 1 ;;
  esac
  file="$(evacuated_file "$node")"
  if [[ -s "$file" ]]; then
    log "ABORT ${file} exists — guests were evacuated and not returned"
    return 1
  fi
  if run_node "$node" "pgrep -a vzdump" | grep -q .; then
    log "ABORT ${node} vzdump is running"
    return 1
  fi
  pending="$(host_pending "$node")"
  if [[ "$pending" == "0" ]]; then
    log "no patches available host ${node}"
    return 0
  fi
  if [[ "$pending" == "ERR" ]]; then
    log "ABORT ${node} pending count failed"
    return 1
  fi
  log "HOST ${node} pending=${pending} drain to ${dest}"
  if [[ "$node" == "prox1" ]]; then
    hold_nvidia
  fi
  if [[ "$node" == "prox3" ]]; then
    if ! vip_on 136; then
      log "ABORT VIP is not on CT136 — prox3 host patch waits until it is"
      return 1
    fi
    log "MOVE VIP to CT139"
    run_node prox3 "pct exec 136 -- systemctl stop keepalived" || return 1
    if ! wait_vip 139 || ! haproxy_health; then
      log "ABORT VIP did not move to CT139"
      run_node prox3 "pct exec 136 -- systemctl start keepalived" || true
      return 1
    fi
  fi
  if ! migrate_away "$node" "$dest"; then
    migrate_back "$node" || true
    if [[ "$node" == "prox3" ]]; then
      run_node prox3 "pct exec 136 -- systemctl start keepalived" || true
    fi
    return 1
  fi
  if ! run_node "$node" "bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get upgrade -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold'"; then
    log "ABORT ${node} apt failed — not rebooted"
    migrate_back "$node" || true
    if [[ "$node" == "prox3" ]]; then
      run_node prox3 "pct exec 136 -- systemctl start keepalived" || true
    fi
    return 1
  fi
  log "REBOOT ${node}"
  if [[ "$(hostname -s)" == "$node" ]]; then
    cat > /etc/systemd/system/patch-cadence-return.service << 'EOF'
[Unit]
Description=Return guests evacuated by patch-cadence
After=pve-cluster.service pvedaemon.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/patch-cadence.sh return prox1
TimeoutStartSec=3600
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable patch-cadence-return.service
    systemctl reboot
    exit 0
  fi
  run_node "$node" "systemctl reboot" || true
  if ! wait_node "$node"; then
    log "ABORT ${node} did not return — guests left on ${dest}"
    return 1
  fi
  verify_host_net "$node" || true
  migrate_back "$node" || return 1
  if [[ "$node" == "prox3" ]]; then
    run_node prox3 "pct exec 136 -- systemctl start keepalived" || return 1
    if ! wait_vip 136 || ! haproxy_health; then
      log "ABORT VIP did not return to CT136"
      return 1
    fi
    log "VIP back on CT136"
  fi
  log "HOST ${node} done"
}

mode_truenas_check() {
  local ver status
  if ! ver="$(truenas_ssh "midclt call system.version" 2>/dev/null)"; then
    log "SKIP truenas ssh failed"
    return 0
  fi
  status="$(truenas_ssh "midclt call update.check_available" 2>/dev/null || echo unavailable)"
  ver="${ver//\"/}"
  log "TRUENAS ${ver} update=${status}"
  if printf '%s' "$status" | grep -q UNAVAILABLE; then
    log "no patches available truenas"
  else
    log "TrueNAS reports an update. It is not applied from the cron. A reboot pauses every guest disk."
  fi
}

mode_return() {
  local node="${1:-prox1}" i
  for i in $(seq 1 30); do
    pct list >/dev/null 2>&1 && break
    sleep 10
  done
  if [[ ! -s "$(evacuated_file "$node")" ]]; then
    log "no evacuated guests for ${node}"
    systemctl disable patch-cadence-return.service >/dev/null 2>&1 || true
    return 0
  fi
  migrate_back "$node" || return 1
  systemctl disable patch-cadence-return.service >/dev/null 2>&1 || true
  log "returned guests to ${node}"
}

mode_truenas_apply() {
  mode_truenas_check
  log "truenas-apply does not reboot TrueNAS. Apply an available update from the TrueNAS UI on its own Saturday."
}

mode_saturday() {
  local n
  PG_DID_WORK=0
  mode_postgres_primary || return 1
  if [[ "$PG_DID_WORK" == "1" ]]; then
    log "saturday stopped after the postgres procedure"
    return 0
  fi
  n="$(host_pending prox1)"
  if [[ "$n" == "ERR" ]]; then
    log "ABORT saturday could not read prox1"
    return 1
  fi
  if [[ "$n" != "0" ]]; then
    log "saturday action prox1 pending=${n}"
    mode_host prox1
    return
  fi
  log "no patches available prox1"
  mode_truenas_check
}

mode_promote() {
  local app="$1" spec name acl blue green port path backend stand live alt node id
  for spec in "${PAIRS[@]}"; do
    IFS='|' read -r name acl blue green port path <<<"$spec"
    [[ "$name" == "$app" ]] || continue
    backend="$(live_backend "$acl")"
    stand="$(standby_ct "$acl" "$blue" "$green")"
    if [[ -z "$backend" || -z "$stand" ]]; then
      log "ABORT ${app} backend unclear (${backend:-empty})"
      return 1
    fi
    if [[ "$backend" == *green* ]]; then
      alt="${backend/green/blue}"
      live="$green"
    else
      alt="${backend/blue/green}"
      live="$blue"
    fi
    log "PROMOTE ${app} ${backend} -> ${alt} after CT${stand} health"
    health_ct "$stand" "$port" "$path" || { log "ABORT standby health failed — traffic stays"; return 1; }
    local where
    where="$(haproxy_target)"
    node="${where%% *}"
    id="${where##* }"
    run_node "$node" "pct exec $id -- grep -q '^backend ${alt}$' /etc/haproxy/haproxy.cfg" || {
      log "ABORT backend ${alt} does not exist"
      return 1
    }
    local hap
    for hap in "prox3 136" "prox2 139"; do
      node="${hap%% *}"
      id="${hap##* }"
      if ! run_node "$node" "pct exec $id -- python3 -c \"
import pathlib
p=pathlib.Path('/etc/haproxy/haproxy.cfg')
text=p.read_text()
pathlib.Path('/etc/haproxy/haproxy.cfg.bak-promote').write_text(text)
acl='$acl'
neu='$alt'
out=[]
for line in text.splitlines(True):
    parts=line.split()
    if len(parts)>=3 and parts[0]=='use_backend' and parts[-1]==acl:
        parts[1]=neu
        nl=chr(10)
        line=' '.join(parts)+(nl if line.endswith(nl) else '')
    out.append(line)
p.write_text(''.join(out))
\""; then
        log "ABORT could not edit HAProxy on CT${id}"
        return 1
      fi
      if ! run_node "$node" "pct exec $id -- haproxy -c -f /etc/haproxy/haproxy.cfg"; then
        log "ABORT config test failed — restoring CT${id}"
        run_node "$node" "pct exec $id -- cp -a /etc/haproxy/haproxy.cfg.bak-promote /etc/haproxy/haproxy.cfg" || true
        return 1
      fi
      run_node "$node" "pct exec $id -- systemctl reload haproxy" || return 1
    done
    log "SWITCHED ${app} to ${alt}"
    upgrade_ct "$live" || return 1
    health_ct "$live" "$port" "$path" || log "WARN old live CT${live} health failed after patch"
    log "Did not switch back."
    return 0
  done
  log "ABORT unknown app ${app}"
  return 1
}

if [[ -f "$STATE_DIR/HOLD" && "$MODE" != "check" && "$MODE" != "plan" && "$MODE" != "return" ]]; then
  log "HELD ${MODE} ${TARGET}"
  notify
  exit 0
fi

if [[ "$MODE" != "check" && "$MODE" != "plan" ]]; then
  exec 9>"/var/lock/patch-cadence.lock"
  if ! flock -n 9; then
    log "already running"
    notify
    exit 0
  fi
fi

rc=0
case "$MODE" in
  check) mode_check || rc=$? ;;
  plan) mode_plan || rc=$? ;;
  patch-standby) mode_patch_standby || rc=$? ;;
  ring2) mode_ring2 || rc=$? ;;
  ring3) mode_ring3 || rc=$? ;;
  host) mode_host "$TARGET" || rc=$? ;;
  saturday) mode_saturday || rc=$? ;;
  haproxy) mode_haproxy || rc=$? ;;
  postgres-replica) mode_postgres_replica || rc=$? ;;
  postgres-primary) mode_postgres_primary || rc=$? ;;
  postgres-plan) mode_postgres_plan || rc=$? ;;
  vaultwarden-backup) mode_vaultwarden 172 backup || rc=$? ;;
  vaultwarden-primary) mode_vaultwarden 171 primary || rc=$? ;;
  truenas-check) mode_truenas_check || rc=$? ;;
  truenas-apply) mode_truenas_apply || rc=$? ;;
  return) mode_return "$TARGET" || rc=$? ;;
  promote) mode_promote "$TARGET" || rc=$? ;;
  *)
    echo "usage: patch-cadence.sh check|plan|patch-standby|ring2|ring3|host <node>|saturday|promote <app>|postgres-primary|postgres-replica|haproxy|vaultwarden-backup|vaultwarden-primary|truenas-check|truenas-apply" >&2
    exit 2
    ;;
esac
notify
log "WROTE $LOG rc=${rc}"
exit "$rc"
