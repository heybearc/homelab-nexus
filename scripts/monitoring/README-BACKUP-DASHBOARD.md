# Proxmox Backup Dashboard

**Dashboard URL:** https://grafana.cloudigan.net/d/25c5f3c7-e17b-4672-9268-812556d75276/proxmox-backups  
**Dashboard ID:** 21  
**Created:** April 18, 2026

---

## Overview

Comprehensive Grafana dashboard for monitoring Proxmox container backup status across all 40 containers.

### Data Source
- **Prometheus** metrics from `/var/lib/node_exporter/textfile_collector/backup_metrics.prom`
- Metrics collected hourly by `/usr/local/bin/backup-metrics.sh` on Proxmox host
- Metric: `proxmox_backup_last_success{ctid="XXX"}` - Unix timestamp of last successful backup

---

## Dashboard Panels

### Row 1: Overview Stats (4 panels)

1. **Backup Coverage Overview**
   - Shows total number of containers with backups
   - Green: ≥38 containers, Yellow: 30-37, Red: <30

2. **Containers Without Recent Backups**
   - Counts containers with no backup or >48 hours old
   - Green: 0, Yellow: 1-4, Red: ≥5

3. **Oldest Backup Age**
   - Shows age of the oldest backup across all containers
   - Green: <48h, Yellow: 48h-7d, Red: >7d

4. **Last Metrics Update**
   - Time since metrics were last collected
   - Green: <2h, Yellow: 2-4h, Red: >4h

### Row 2: Detailed Views (2 panels)

5. **Backup Age by Container** (Bar Gauge)
   - Horizontal bar chart showing backup age for each container
   - Color-coded: Green (<48h), Yellow (48h-7d), Red (>7d)
   - Sorted by age for easy identification of stale backups

6. **Last Successful Backup Time** (Table)
   - Sortable table with all containers and their last backup time
   - Shows time as "X hours/days ago"
   - Sorted by oldest first by default

### Row 3: Trend Analysis (1 panel)

7. **Backup Age Trend - Last 7 Days** (Time Series)
   - Line graph showing backup age over time for Tier 1 containers
   - Helps identify backup job failures or patterns
   - Shows min/max/current values in legend

### Row 4: Problem Detection (2 panels)

8. **Containers Missing Backups** (Table)
   - Lists containers with no backups (metric = 0)
   - Empty table = all containers have backups ✅

9. **Stale Backups >48 hours** (Table)
   - Lists containers with backups older than 48 hours
   - Shows exact time of last backup
   - Useful for identifying backup job issues

---

## Color Coding

**Backup Age Thresholds:**
- 🟢 Green: 0-48 hours (healthy)
- 🟡 Yellow: 48 hours - 7 days (warning)
- 🔴 Red: >7 days (critical)

**Coverage Thresholds:**
- 🟢 Green: ≥38/40 containers (95%+)
- 🟡 Yellow: 30-37 containers (75-94%)
- 🔴 Red: <30 containers (<75%)

---

## Alerts & Actions

### When to Investigate

1. **Red stat panels** - Immediate attention required
2. **Yellow stat panels** - Review within 24 hours
3. **Entries in "Stale Backups" table** - Check backup job logs
4. **Entries in "Missing Backups" table** - Verify container is in backup job

### Troubleshooting Steps

**If backups are stale:**
```bash
# Check backup job status
ssh prox "pvesh get /cluster/backup --output-format=json-pretty"

# Check recent backup logs
ssh prox "tail -50 /var/log/vzdump.log"

# Verify storage is accessible
ssh prox "pvesm status | grep truenas"

# List recent backups for specific container
ssh prox "pvesm list truenas-backups | grep 'lxc-131'"
```

**If metrics are stale:**
```bash
# Check if metrics script is running
ssh prox "cat /var/lib/node_exporter/textfile_collector/backup_metrics.prom"

# Manually run metrics collection
ssh prox "/usr/local/bin/backup-metrics.sh"

# Verify cron is configured
ssh prox "crontab -l | grep backup-metrics"
```

---

## Maintenance

### Dashboard Updates

To update the dashboard:
1. Edit `proxmox-backup-dashboard.json`
2. Run `./import-backup-dashboard.sh`
3. Dashboard will be updated (overwrite: true)

### Re-import Dashboard

```bash
cd /Users/cory/Projects/homelab-nexus/scripts/monitoring
./import-backup-dashboard.sh
```

### Export Dashboard from Grafana

1. Go to dashboard settings (gear icon)
2. Click "JSON Model"
3. Copy JSON
4. Save to `proxmox-backup-dashboard.json`

---

## Metrics Details

### Metric Format
```prometheus
proxmox_backup_last_success{ctid="100"} 1776463635
proxmox_backup_last_success{ctid="101"} 1776463890
...
proxmox_backup_metrics_updated 1776463635
```

### Metric Collection
- **Script:** `/usr/local/bin/backup-metrics.sh` (Proxmox host)
- **Schedule:** Hourly (cron: `0 * * * *`)
- **Source:** `pvesm list truenas-backups`
- **Export:** `/var/lib/node_exporter/textfile_collector/backup_metrics.prom`

### Prometheus Scrape
- Node exporter on Proxmox host exposes textfile collector metrics
- Prometheus scrapes from node_exporter endpoint
- Metrics available in Grafana via Prometheus data source

---

## Dashboard Features

✅ Auto-refresh every 5 minutes  
✅ Time range selector (default: last 24 hours)  
✅ All panels use Prometheus as data source  
✅ Color-coded thresholds for quick status assessment  
✅ Sortable and filterable tables  
✅ Hover tooltips with detailed information  
✅ Legend with min/max/current values on time series  
✅ Responsive layout (24-column grid)

---

## Related Documentation

- `BACKUP-STATUS-2026-04-17.md` - Complete backup implementation status
- `BACKUP-IMPLEMENTATION-GUIDE.md` - Original implementation guide
- `PROXMOX-BACKUP-STRATEGY.md` - Backup strategy and design

---

**Last Updated:** April 18, 2026  
**Maintained By:** Infrastructure Team
