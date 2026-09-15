# App monitoring lifecycle (Prometheus + Alertmanager + Watchdog + Uptime Kuma)

**Registry:** `monitoring/apps-registry.yaml` — single source of truth  
**Sync:** `./scripts/monitoring/sync-monitoring-stack.sh`  
**Decommission:** `./scripts/monitoring/decommission-app.sh <app_id>`

---

## Architecture

```
apps-registry.yaml
       │
       ├─► Prometheus scrape targets (CT150)     ──► Alert rules (homelab.yml)
       ├─► Watchdog instances.json (CT150:9099)  ──► Proxmox start / PG failover
       ├─► Alertmanager routes                   ──► email + n8n + watchdog + PG failover
       └─► uptime hints (manual / n8n sync)        ──► Uptime Kuma (CT153)
```

**Alert flow**

1. Prometheus fires alert (only targets with label `monitor: "true"` affect `ContainerDown`)
2. Alertmanager routes:
   - **watchdog** — `ContainerDown` / `BotContainerDown` → auto-restart LXC (CT150:9099)
   - **n8n-webhook** — all alerts → Zammad/Vikunja workflow
   - **email-cory** — default HTML email
   - **postgresql-failover** — `action: failover` → Semaphore (CT150:9098)

---

## New app checklist (do every deploy)

### 1. Provisioning (during Ansible deploy)

- [ ] Run `scripts/provisioning/install-monitoring.sh <ctid> <name>` on **each** LXC (node_exporter + promtail + UFW 9100)
- [ ] Confirm app entry exists in `monitoring/apps-registry.yaml` (or use `register-app.sh`)

```bash
# Example: blue-green app
BLUE_CTID=193 BLUE_IP=10.92.3.96 GREEN_CTID=194 GREEN_IP=10.92.3.97 \
  PUBLIC_URL=https://hub.cloudigan.net \
  ./scripts/monitoring/register-app.sh chapter-hub production
# Edit registry for app_metrics / postgres_exporter if needed
```

### 2. Sync monitoring stack

```bash
./scripts/monitoring/sync-monitoring-stack.sh
```

This deploys Prometheus config, alert rules, Watchdog map, Alertmanager watchdog route, and opens UFW for scraping.

### 3. Uptime Kuma (external URLs)

Run n8n workflow **Uptime Kuma · Sync Monitors** or:

```bash
curl -X POST -H "X-Sync-Token: $(ssh prox 'pct exec 153 -- cat /opt/uptime-kuma-app/.sync-token')" \
  http://10.92.3.82:18771/sync
```

Add public URLs to the app's `uptime:` block in the registry first.

### 4. HAProxy / NPM / DNS

Use existing app deploy playbooks (`configure-*-haproxy.yml`, NPM, DC-01 DNS). Not auto-generated from registry yet.

### 5. Verify

```bash
ssh prox "pct exec 150 -- curl -s localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.health!=\"up\") | .labels.instance'
ssh prox "pct exec 150 -- curl -s localhost:9099/health"
ssh prox "pct exec 150 -- amtool config routes --alertmanager.url=http://127.0.0.1:9093"
```

---

## Decommission checklist

```bash
./scripts/monitoring/decommission-app.sh quantshift
```

This sets `state: archived` and runs sync (removes Prometheus/Watchdog entries).

**Manual steps** (same order every time):

1. Archive in `monitoring/apps-registry.yaml` + sync (automated by script above)
2. Uptime Kuma sync (remove stale monitors)
3. HAProxy backends + ACLs
4. NPM proxy host + SSL cert
5. AdGuard / DC-01 DNS
6. Netbox IPAM
7. App-specific Grafana dashboards
8. Destroy Proxmox CT/VM
9. MCP `homelab-blue-green` server.js if blue-green app

Archived apps stay in the registry for history but are **not scraped** and **not restarted** by Watchdog.

---

## Registry fields

| Field | Purpose |
|-------|---------|
| `id` | App identifier (matches MCP / docs) |
| `state` | `active` \| `paused` \| `archived` |
| `tier` | `production` \| `infrastructure` \| `media` \| `sandbox` |
| `instances` | Prometheus node_exporter targets + Watchdog CT map |
| `app_metrics` | Optional HTTP metrics scrape (e.g. cloudigan-api `/metrics`) |
| `postgres_exporter` / `haproxy_exporter` | Specialized exporters |
| `uptime` | Hints for Uptime Kuma sync script |
| `watchdog_failover` | Use PG failover script instead of simple restart |
| `custom_jobs` | TrueNAS exporter, Windows VM, etc. |

**States**

- **active** — full monitoring + watchdog
- **paused** — still in registry but excluded from `ContainerDown` noise (TrueNAS, Windows VM off)
- **archived** — decommissioned; no scrape, no watchdog

---

## Ansible integration

After any deploy playbook:

```yaml
- name: Sync monitoring stack from registry
  ansible.builtin.include_tasks: tasks/sync-monitoring-stack.yml
```

Or run directly:

```bash
cd ansible && ansible-playbook playbooks/sync-monitoring-stack.yml
```

---

## Files

| Path | Role |
|------|------|
| `monitoring/apps-registry.yaml` | Source of truth |
| `scripts/monitoring/generate-monitoring-config.py` | Generator |
| `scripts/monitoring/sync-monitoring-stack.sh` | Deploy to CT150 |
| `scripts/monitoring/watchdog.py` | Watchdog service |
| `monitoring/prometheus-rules/homelab.yml` | Alert rules |
| `scripts/uptime-kuma/sync-uptime-kuma-monitors.sh` | Uptime Kuma dedupe/add |

---

## Alertmanager → n8n → Zammad (tickets open AND close)

**Yes** — Prometheus and Uptime Kuma alerts should create Zammad tickets. Both workflows now:

| Event | Action |
|-------|--------|
| **Alert firing / monitor DOWN** | Search for open ticket with matching fingerprint tag; create if none exists |
| **Alert resolved / monitor UP** | Find open ticket by tag; close with resolution note (auto-heal / recovered) |

**Fingerprint tags** (dedupe + close matching):
- Prometheus: `alert-fp-{alertname}-{instance}` (e.g. `alert-fp-ContainerDown-postgres`)
- Uptime Kuma: `alert-fp-uptime-{monitor-name}`

**Deploy / update workflows:**
```bash
source .env
N8N_API_URL=http://10.92.3.79:5678/api/v1 python3 scripts/monitoring/deploy-zammad-alert-workflows.py
```

**Requires:** Alertmanager `n8n-webhook` receiver with `send_resolved: true` (already configured).

Watchdog auto-restarts do not notify Zammad directly — when the container recovers, Prometheus sends `resolved` and n8n closes the ticket.

### Why leftovers pile up (fixed 2026-09-03)

Zammad's `/tickets/search` returns a **JSON array**, not `{ tickets_count, tickets }`. The n8n "Has Open Ticket?" check used `$json.tickets_count`, which is always 0 on an array — so **resolved alerts never closed support tickets**, and Vikunja tasks were never completed at all.

Fixes:
- n8n search nodes now count `Array.isArray($json) ? $json.length : …`
- **Ops Hub · Alert Healer** (every 10 min) asks Prometheus `/api/v1/alerts` what is still firing, then closes matching Vikunja Inbox tasks **and** Zammad tickets whose title is `[CRITICAL|WARNING] AlertName: instance`. That is the validation path: we do not trust the webhook alone.
- Ops Hub **Monitoring alerts** card shows recovered vs still-firing, with a manual **Close recovered** button.

```bash
curl -s http://10.92.3.83:3002/alerts          # dry run
curl -s -X POST http://10.92.3.83:3002/alerts/heal
```

---

## Troubleshooting

**ContainerDown but CT is running**  
- node_exporter not installed → `install-monitoring.sh`  
- UFW blocking 9100 → sync opens `10.92.3.0/24`; re-run sync  
- Wrong IP in registry → fix registry + sync  

**Watchdog not restarting**  
- Check `curl http://10.92.3.2:9099/health` — `mapped_instances` count  
- Instance must be in `instances.json` with `state: active`  
- Archived instances are skipped  

**Alert noise during rack moves**  
- Set app `state: paused` for targets that are expected down (TrueNAS, Windows VM)  
- Or `state: archived` for decommissioned stacks  

---

**Last updated:** 2026-06-06
