#!/usr/bin/env bash
# Detect Reolink/Baichuan reconnect storms and restart Scrypted when streams are dead.
# Cameras stay reachable on :9000 while the plugin spins connect/disconnect with no video.
set -euo pipefail

WINDOW_MIN="${SCRYPTED_WATCH_WINDOW_MIN:-3}"
DISCONNECT_THRESHOLD="${SCRYPTED_WATCH_DISCONNECT_THRESHOLD:-40}"
COOLDOWN_SEC="${SCRYPTED_WATCH_COOLDOWN_SEC:-1200}"
STATE_DIR="${SCRYPTED_WATCH_STATE:-/var/lib/scrypted-watchdog}"
TEXTFILE_DIR="${SCRYPTED_WATCH_TEXTFILE:-/var/lib/node_exporter/textfile}"
STAMP="$STATE_DIR/last-restart"
METRICS="$TEXTFILE_DIR/scrypted.prom"

mkdir -p "$STATE_DIR" "$TEXTFILE_DIR"

now="$(date +%s)"
last=0
[[ -f "$STAMP" ]] && last="$(cat "$STAMP" 2>/dev/null || echo 0)"
elapsed=$((now - last))

since="${WINDOW_MIN} minutes ago"
window_start=$((now - WINDOW_MIN * 60))
if (( last > window_start )); then
  since="$(date -d "@$last" '+%Y-%m-%d %H:%M:%S')"
fi
journal="$(journalctl -u scrypted --since "$since" --no-pager 2>/dev/null || true)"

disconnects=$(printf '%s\n' "$journal" | grep -c 'BaichuanClient] disconnected' || true)
idle=$(printf '%s\n' "$journal" | grep -c 'No stream activity' || true)
parser=$(printf '%s\n' "$journal" | grep -c 'parser exited' || true)
svc="$(systemctl is-active scrypted || true)"

healthy=1
if [[ "$svc" != "active" ]]; then
  healthy=0
elif (( disconnects >= DISCONNECT_THRESHOLD )); then
  healthy=0
fi
restarts_total=0
[[ -f "$STATE_DIR/restarts" ]] && restarts_total="$(cat "$STATE_DIR/restarts" 2>/dev/null || echo 0)"

restarted=0
if (( healthy == 0 )); then
  if (( elapsed >= COOLDOWN_SEC )) && [[ "$svc" != "activating" ]]; then
    echo "$(date -Is) storm: disconnects=${disconnects} idle=${idle} parser=${parser} svc=${svc} — restarting scrypted" >&2
    if systemctl restart scrypted; then
      echo "$now" > "$STAMP"
      last="$now"
      restarts_total=$((restarts_total + 1))
      echo "$restarts_total" > "$STATE_DIR/restarts"
      restarted=1
    fi
  else
    echo "$(date -Is) storm: disconnects=${disconnects} cooldown ${elapsed}/${COOLDOWN_SEC}s" >&2
  fi
fi

tmp="${METRICS}.$$"
cat > "$tmp" <<EOF
# HELP scrypted_baichuan_disconnects Baichuan TCP disconnects in the watch window
# TYPE scrypted_baichuan_disconnects gauge
scrypted_baichuan_disconnects{window="${WINDOW_MIN}m"} ${disconnects}
# HELP scrypted_stream_idle_restarts Native rfc4571 idle-watchdog restarts in the watch window
# TYPE scrypted_stream_idle_restarts gauge
scrypted_stream_idle_restarts{window="${WINDOW_MIN}m"} ${idle}
# HELP scrypted_parser_errors rfc4571 parser-exited errors in the watch window
# TYPE scrypted_parser_errors gauge
scrypted_parser_errors{window="${WINDOW_MIN}m"} ${parser}
# HELP scrypted_stream_healthy 1 if Scrypted service is active and not in a reconnect storm
# TYPE scrypted_stream_healthy gauge
scrypted_stream_healthy ${healthy}
# HELP scrypted_watchdog_restarts_total Times this watchdog restarted scrypted.service
# TYPE scrypted_watchdog_restarts_total counter
scrypted_watchdog_restarts_total ${restarts_total}
# HELP scrypted_watchdog_last_restart_timestamp Unix time of last watchdog restart (0 = never)
# TYPE scrypted_watchdog_last_restart_timestamp gauge
scrypted_watchdog_last_restart_timestamp ${last}
# HELP scrypted_watchdog_restarted 1 if this check restarted Scrypted
# TYPE scrypted_watchdog_restarted gauge
scrypted_watchdog_restarted ${restarted}
EOF
mv "$tmp" "$METRICS"
chmod 644 "$METRICS"
