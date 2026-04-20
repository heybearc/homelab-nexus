# Redis Shared Instance — CT192

**Status:** ✅ Live  
**Date Deployed:** 2026-04-20  
**Purpose:** Shared Redis instance for all homelab applications

---

## Container Details

| Field | Value |
|---|---|
| **CTID** | 192 |
| **Hostname** | redis-shared |
| **IP Address** | 10.92.3.93 |
| **Port** | 6379 |
| **CPU** | 2 cores |
| **RAM** | 512 MB |
| **Disk** | 8 GB |
| **OS** | Ubuntu 22.04 |
| **Function** | core/utility |

---

## Connection Details

**Host:** `10.92.3.93`  
**Port:** `6379`  
**Password:** Stored in Bitwarden as `redis-shared-homelab` — value: `x8vpaV6LDM8IhQq0vMU4xfpRB326gbKD`

**Test connectivity:**
```bash
redis-cli -h 10.92.3.93 -p 6379 -a 'PASSWORD' ping
# Returns: PONG
```

---

## Database Assignment Map

| DB | Application | Usage |
|---|---|---|
| `db=0` | **TIP Generator** | Session cache, API rate limiting |
| `db=1` | **TheoShift** | Session cache, job queue |
| `db=2` | **LeadIQ** | Session cache, API cache |
| `db=3` | **QuantShift** | Session/state cache |
| `db=4` | **Cloudigan API** | Session cache |
| `db=5` | **n8n** | Workflow state (if needed) |
| `db=6–15` | Reserved | Future applications |

---

## Redis Configuration

**Config file:** `/etc/redis/redis.conf`

Key settings applied:
```
bind 0.0.0.0
requirepass <strong-password>
protected-mode no
```

**Service:** `systemctl status redis-server`

---

## Wiring Applications

### TIP Generator (db=0)
```env
REDIS_URL=redis://:x8vpaV6LDM8IhQq0vMU4xfpRB326gbKD@10.92.3.93:6379/0
```

### TheoShift (db=1)
```env
REDIS_URL=redis://:x8vpaV6LDM8IhQq0vMU4xfpRB326gbKD@10.92.3.93:6379/1
```

### LeadIQ (db=2)
```env
REDIS_URL=redis://:x8vpaV6LDM8IhQq0vMU4xfpRB326gbKD@10.92.3.93:6379/2
```

---

## Maintenance

**SSH access:**
```bash
ssh root@10.92.3.93
```

**Check status:**
```bash
ssh root@10.92.3.93 "redis-cli -a PASSWORD info server | grep -E 'version|uptime|connected'"
```

**Monitor live commands:**
```bash
ssh root@10.92.3.93 "redis-cli -a PASSWORD monitor"
```

---

## Monitoring

- Node exporter running on port `9100` (scraped by Prometheus CT150)
- Promtail running (logs shipped to Loki)
- Backup configured to TrueNAS via Proxmox backup schedule

---

**Next Steps:**
- [ ] Wire TIP Generator to `db=0`
- [ ] Add `REDIS_URL` to TheoShift env
- [ ] Add `REDIS_URL` to LeadIQ env
- [ ] Add Redis monitoring dashboard to Grafana
