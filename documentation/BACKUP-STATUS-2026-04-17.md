# Backup Implementation Status

**Date:** 2026-04-17  
**Status:** ✅ FULLY IMPLEMENTED  
**Coverage:** 100% (40/40 containers)

---

## 🎯 Summary

All backup systems are now operational with comprehensive coverage across all infrastructure components.

### Quick Stats
- **Container Backups:** 40/40 containers (100% coverage)
- **Storage Backend:** TrueNAS NFS (24.9TB available)
- **Database Backups:** PostgreSQL (16 databases) + NPM SQLite
- **Monitoring:** Prometheus metrics + hourly collection
- **Retention:** Tiered (daily/weekly/monthly)

---

## 📦 Container Backup Jobs

### Tier 1: Critical Production (Daily)
**Schedule:** Daily at midnight  
**Containers:** 14 containers  
**VMIDs:** 131, 132, 133, 134, 135, 136, 137, 138, 139, 141, 150, 151, 181, 182

**Services:**
- PostgreSQL (CT131, CT151) - Primary & Replica
- TheoShift (CT132, CT134) - Blue/Green
- LDC Tools (CT133, CT135) - Blue/Green  
- HAProxy (CT136, CT139) - Primary/Standby
- QuantShift (CT137, CT138) - Blue/Green
- Netbox (CT141)
- Monitoring (CT150)
- Cloudigan API (CT181, CT182) - Blue/Green

**Retention:** Managed by Proxmox (default)  
**Compression:** ZSTD  
**Mode:** Snapshot

### Tier 2: Important Services (Weekly)
**Schedule:** Sunday at 3:00 AM  
**Containers:** 6 containers  
**VMIDs:** 100, 101, 115, 119, 121, 140

**Services:**
- QuantShift Bots (CT100, CT101)
- QA Environment (CT115)
- BNI Dev (CT119)
- Nginx Proxy Manager (CT121)
- AdGuard DNS (CT140)

**Retention:** Managed by Proxmox  
**Compression:** ZSTD  
**Mode:** Snapshot

### Tier 3: Media Stack (Monthly)
**Schedule:** 1st of month  
**Containers:** 6 containers  
**VMIDs:** 120, 124, 125, 127, 128, 129

**Services:**
- Readarr (CT120)
- Radarr (CT124)
- Sonarr (CT125)
- SABnzbd (CT127)
- Plex (CT128)
- Calibre-web (CT129)

**Retention:** Managed by Proxmox  
**Compression:** ZSTD  
**Mode:** Snapshot

### Individual Daily Backups
**Schedule:** Daily  
**Containers:** 14 containers  
**VMIDs:** 111, 130, 142, 152, 153, 170, 180, 183, 184, 185, 186, 187, 188, 189

**Services:**
- Ansible Semaphore (CT111)
- Kasm Workspaces (CT130)
- Kimai Time Tracking (CT142)
- LibreNMS (CT152)
- Uptime Kuma (CT153)
- BookStack (CT170)
- Scrypted NVR (CT180)
- Plane Project Management (CT183)
- Authentik SSO (CT184)
- Zammad Support (CT185)
- Vikunja Tasks (CT189)
- n8n Automation (CT188)
- Other services (CT186, CT187)

---

## 💾 Database-Specific Backups

### PostgreSQL (CT131)
**Script:** `/usr/local/bin/backup-postgres.sh`  
**Schedule:** Daily at 1:00 AM (before container backups)  
**Location:** `/var/backups/postgresql/`  
**Retention:** 14 days local

**Databases Backed Up (16):**
- `bni_toolkit`
- `bookstack`
- `cloudigan_authentik`
- `cloudigan_kimai`
- `cloudigan_n8n`
- `cloudigan_plane`
- `cloudigan_support`
- `cloudigan_vikunja`
- `ldc_tools`
- `leadiq`
- `quantshift`
- `semaphore`
- `theoshift_scheduler`
- `zammad_production`
- `zammad_support`
- `zammad_tickets`

**Format:** `pg_dump` → gzip  
**Cron:** `0 1 * * * /usr/local/bin/backup-postgres.sh`

### NPM SQLite (CT121)
**Script:** `/usr/local/bin/backup-npm-db.sh` (on Proxmox host)  
**Schedule:** Daily at 2:00 AM  
**Locations:**
- Primary: `/mnt/pve/media-pool/backups/npm/database/`
- Local: `/hdd-pool/backups/npm-database/`

**Retention:**
- TrueNAS: 60 days
- Local: 7 days

**Format:** Direct file copy → gzip  
**Cron:** `0 2 * * * /usr/local/bin/backup-npm-db.sh`

**Status:** ✅ Fixed April 17, 2026 (was broken since March 22 due to incorrect path)

### Scrypted Database
**Script:** `/root/backup-scrypted-db.sh` (on Proxmox host)  
**Schedule:** Daily at 3:00 AM  
**Log:** `/var/log/scrypted-backup.log`  
**Cron:** `0 3 * * * /root/backup-scrypted-db.sh >> /var/log/scrypted-backup.log 2>&1`

---

## 📊 Backup Monitoring

### Prometheus Metrics
**Script:** `/usr/local/bin/backup-metrics.sh` (on Proxmox host)  
**Schedule:** Hourly  
**Metrics File:** `/var/lib/node_exporter/textfile_collector/backup_metrics.prom`  
**Cron:** `0 * * * * /usr/local/bin/backup-metrics.sh`

**Metrics Collected:**
- `proxmox_backup_last_success{ctid="XXX"}` - Unix timestamp of last successful backup per container
- `proxmox_backup_metrics_updated` - Last metrics collection time

**Implementation:** April 17, 2026

### Email Notifications
**Configuration:** Proxmox backup jobs configured with `mailnotification failure`  
**Trigger:** Backup job failures  
**Status:** ✅ Enabled on all backup jobs

### Grafana Dashboard
**Status:** ✅ DEPLOYED  
**URL:** https://grafana.cloudigan.net/d/25c5f3c7-e17b-4672-9268-812556d75276/proxmox-backups  
**Data Source:** Prometheus  
**Dashboard ID:** 21  
**UID:** 25c5f3c7-e17b-4672-9268-812556d75276

**Panels:**
- ✅ Backup Coverage Overview (stat)
- ✅ Containers Without Recent Backups (stat)
- ✅ Oldest Backup Age (stat)
- ✅ Last Metrics Update (stat)
- ✅ Backup Age by Container (bar gauge)
- ✅ Last Successful Backup Time (table)
- ✅ Backup Age Trend - Last 7 Days (time series)
- ✅ Containers Missing Backups (table)
- ✅ Stale Backups >48 hours (table)

**Deployed:** April 18, 2026

---

## 💿 Storage Backend

### TrueNAS NFS
**Mount Point:** `/mnt/pve/media-pool`  
**NFS Export:** `10.92.5.200:/mnt/media-pool/data/proxmox-backups`  
**Proxmox Storage ID:** `truenas-backups`

**Capacity:**
- Total: 67.5TB
- Used: 42.6TB (63%)
- Available: 24.9TB
- Backup Usage: ~300 backup files

**Status:** ✅ Active and operational

---

## 🔍 Verification Commands

### Check Backup Storage
```bash
ssh prox "pvesm status | grep truenas"
```

### List All Backups
```bash
ssh prox "pvesm list truenas-backups"
```

### Check Backup Jobs
```bash
ssh prox "pvesh get /cluster/backup --output-format=json-pretty"
```

### View Backup Metrics
```bash
ssh prox "cat /var/lib/node_exporter/textfile_collector/backup_metrics.prom"
```

### Check Database Backups
```bash
# PostgreSQL
ssh prox "pct exec 131 -- ls -lh /var/backups/postgresql/"

# NPM
ssh prox "ls -lh /mnt/pve/media-pool/backups/npm/database/"
```

### View Backup Logs
```bash
# PostgreSQL
ssh prox "pct exec 131 -- tail -20 /var/log/postgres-backup.log"

# NPM
ssh prox "tail -20 /var/log/npm-backup.log"

# Scrypted
ssh prox "tail -20 /var/log/scrypted-backup.log"
```

---

## 🚨 Recent Issues Resolved

### Issue 1: NPM Backups Stopped (March 22 - April 17)
**Cause:** CT121 moved from `hdd-pool` to `local-lvm` storage, backup script had hardcoded path  
**Resolution:** Updated script to use `pct pull` to extract database from running container  
**Fixed:** April 17, 2026  
**Status:** ✅ Resolved

### Issue 2: Missing Container Coverage
**Cause:** Only 13 containers had backup jobs configured  
**Resolution:** Added 27 missing containers across 3 tiered backup jobs  
**Fixed:** April 17, 2026  
**Status:** ✅ Resolved

### Issue 3: No PostgreSQL Database Backups
**Cause:** Script documented but never deployed  
**Resolution:** Implemented `/usr/local/bin/backup-postgres.sh` on CT131 with cron  
**Fixed:** April 17, 2026  
**Status:** ✅ Resolved

### Issue 4: No Backup Monitoring
**Cause:** Monitoring script documented but never deployed  
**Resolution:** Implemented `/usr/local/bin/backup-metrics.sh` with hourly cron  
**Fixed:** April 17, 2026  
**Status:** ✅ Resolved

---

## 📋 Maintenance Schedule

### Daily (Automated)
- 1:00 AM - PostgreSQL database backups (CT131)
- 2:00 AM - NPM database backup (Proxmox host)
- 3:00 AM - Scrypted database backup (Proxmox host)
- Midnight - Tier 1 container backups (14 containers)
- Midnight - Individual daily container backups (14 containers)
- Hourly - Backup metrics collection

### Weekly (Automated)
- Sunday 3:00 AM - Tier 2 container backups (6 containers)

### Monthly (Automated)
- 1st of month - Tier 3 container backups (6 containers)

### Manual (As Needed)
- Review backup logs for failures
- Verify backup integrity
- Test restore procedures
- Review storage usage trends

---

## ✅ Implementation Checklist

- [x] TrueNAS NFS storage configured and mounted
- [x] Proxmox storage `truenas-backups` added
- [x] Tier 1 backup job configured (14 containers, daily)
- [x] Tier 2 backup job configured (6 containers, weekly)
- [x] Tier 3 backup job configured (6 containers, monthly)
- [x] Individual daily backup jobs (14 containers)
- [x] PostgreSQL backup script deployed to CT131
- [x] PostgreSQL backup cron configured
- [x] NPM backup script fixed and operational
- [x] Scrypted backup script operational
- [x] Backup monitoring metrics deployed
- [x] Backup metrics cron configured
- [x] Email notifications enabled
- [x] Grafana backup dashboard created
- [x] Documentation complete

---

## 🎯 Success Criteria

✅ **100% backup coverage** - All 40 containers backed up  
✅ **Automated retention** - Managed by Proxmox backup jobs  
✅ **Monitoring enabled** - Prometheus metrics collecting hourly  
✅ **Email alerts** - Configured on all backup jobs  
✅ **Grafana dashboard** - Deployed with 9 panels  
✅ **Database backups** - PostgreSQL (16 DBs) + NPM + Scrypted  
✅ **Documentation complete** - All procedures documented

---

## 📚 Related Documentation

- `BACKUP-IMPLEMENTATION-GUIDE.md` - Original implementation plan
- `PROXMOX-BACKUP-STRATEGY.md` - Backup strategy design
- `NPM-BACKUP-RECOVERY-PLAN.md` - NPM-specific procedures

---

**Last Updated:** 2026-04-17  
**Next Review:** 2026-05-17 (monthly)
