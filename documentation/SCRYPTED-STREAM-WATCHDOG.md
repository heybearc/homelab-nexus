# Scrypted stream watchdog

**Container:** CT180 (`scrypted`) — `10.92.3.15`  
**UI:** https://scrypted.cloudigan.net

## Why streams go offline while the container stays up

`scrypted.service` and Prometheus `up{instance="scrypted"}` can stay healthy for weeks while **no video** is delivered.

The Reolink CX810 cameras (Driveway `10.92.0.184`, Garage `10.92.0.189`, Front Porch `10.92.0.190`) stay reachable on Baichuan TCP `:9000` and RTSP `:554`. The native plugin (`@apocaliss92/scrypted-reolink-native`) then storms:

- `[BaichuanClient] disconnected` / reconnect with handshake only (`lastRxCmdId=3`)
- `No stream activity for ~10s` → idle restart
- `parser exited` / `Video codec is not h264` (cameras are H.265)

A `systemctl restart scrypted` on CT180 clears the plugin state. Last manual clear: 2026-08-10. This watchdog automates that.

## Self-heal

On CT180, `scrypted-stream-watchdog.timer` runs every 2 minutes:

1. Count Baichuan disconnects in the last 3 minutes (ignoring logs from before the last restart).
2. If there are **≥ 40** disconnects (or `scrypted.service` is not active), restart `scrypted.service`.
3. **20 minute cooldown** so a restart cannot loop.
4. Export Prometheus textfile metrics via node_exporter (`:9100`).

Install / refresh:

```bash
./scripts/scrypted/install-stream-watchdog.sh
```

Manual restart:

```bash
ssh -F .cloudy-work/ssh_config_master.conf prox 'pct exec 180 -- systemctl restart scrypted'
```

## Alerts (CT150)

Rules in `monitoring/prometheus-rules/homelab.yml` (sync with `scripts/monitoring/sync-monitoring-stack.sh`):

| Alert | Fires when |
|---|---|
| `ScryptedStreamStorm` | `scrypted_baichuan_disconnects{window="3m"} > 40` for 4m |
| `ScryptedStreamsUnhealthy` | `scrypted_stream_healthy == 0` for 8m |

If those stay firing after a watchdog restart, the cameras or plugin need a human (codec / stream count / NFS), not another reboot loop.

## Metrics

```text
scrypted_baichuan_disconnects{window="3m"}
scrypted_stream_idle_restarts{window="3m"}
scrypted_parser_errors{window="3m"}
scrypted_stream_healthy
scrypted_watchdog_restarts_total
scrypted_watchdog_last_restart_timestamp
scrypted_watchdog_restarted
```
