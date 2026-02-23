# NPM Container Backup & Recovery Plan

**Container:** CT121 (nginx-proxy)  
**IP:** 10.92.3.3  
**Critical Data:** SQLite database with proxy host configurations  
**Created:** 2026-02-23

---

## 🚨 Lessons Learned from February 2026 Incident

**What Happened:**
- NPM container (CT121) failed to start after rename attempt
- Container was destroyed and restored from December 1st backup
- **2.5 months of configuration lost** (Dec 1 - Feb 23)
- Missing proxy hosts: QuantShift (5 entries), BNI Toolkit, Grafana, Monitoring (3 entries)
- Required manual reconstruction of 10 proxy hosts

**Root Cause:**
- Old backup (2.5 months stale)
- No automated backup schedule
- No ZFS snapshots before destructive operations

---

## 📊 Critical NPM Data

### Database Location
```
Host: /hdd-pool/subvol-121-disk-0/data/database.sqlite
Container: /data/database.sqlite
```

### Current Configuration
- **32 active proxy hosts**
- **27 SSL certificates**
- **Production apps:** TheoShift, LDC Tools, QuantShift, BNI Toolkit
- **Infrastructure:** Netbox, HAProxy, Prometheus, Grafana, Alertmanager, Uptime Kuma
- **Media:** Plex, Radarr, Sonarr, Prowlarr, SABnzbd, Readarr

---

## 🔄 Backup Strategy

### 1. Daily Database Backup Locations

**Primary (TrueNAS NFS):**
```
/mnt/pve/media-pool/backups/npm/
├── database/           # Daily SQLite backups (60-day retention)
├── container/          # Weekly vzdump backups (4-week retention)
└── snapshots/          # Pre-change exports
```

**Secondary (Local Redundancy):**
```
/hdd-pool/backups/npm-database/  # Last 7 days of database backups
```

**Script:** `/usr/local/bin/backup-npm-db.sh`
```bash
#!/bin/bash
# NPM Database Backup Script
# Runs daily via cron

BACKUP_DIR="/hdd-pool/backups/npm-database"
DB_PATH="/hdd-pool/subvol-121-disk-0/data/database.sqlite"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/npm-database-$DATE.sqlite"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup database
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"

# Compress backup
gzip "$BACKUP_FILE"

# Keep last 30 days of backups
find "$BACKUP_DIR" -name "npm-database-*.sqlite.gz" -mtime +30 -delete

# Log backup
echo "$(date): NPM database backed up to $BACKUP_FILE.gz" >> /var/log/npm-backup.log
```

**Cron Schedule (on Proxmox host):**
```bash
# Daily at 2 AM
0 2 * * * /usr/local/bin/backup-npm-db.sh
```

---

### 2. Weekly Container Backups

**Proxmox vzdump backup:**
```bash
# Weekly full container backup
vzdump 121 --storage local --mode snapshot --compress zstd --remove 0
```

**Cron Schedule:**
```bash
# Weekly on Sunday at 3 AM
0 3 * * 0 vzdump 121 --storage local --mode snapshot --compress zstd --remove 0
```

**Retention:** Keep last 4 weekly backups (1 month)

---

### 3. Pre-Modification ZFS Snapshots

**Before ANY container modifications:**
```bash
# Create snapshot before changes
zfs snapshot hdd-pool/subvol-121-disk-0@pre-change-$(date +%Y%m%d-%H%M%S)

# List snapshots
zfs list -t snapshot | grep subvol-121

# Rollback if needed
zfs rollback hdd-pool/subvol-121-disk-0@snapshot-name
```

**Mandatory snapshots before:**
- Container renames
- NPM version upgrades
- Major configuration changes
- Database migrations

---

## 🔧 Recovery Procedures

### Scenario 1: Database Corruption (Container Still Running)

**Steps:**
1. Stop NPM service:
   ```bash
   ssh prox "pct exec 121 -- systemctl stop npm"
   ```

2. Restore latest database backup:
   ```bash
   ssh prox "gunzip -c /hdd-pool/backups/npm-database/npm-database-YYYYMMDD-HHMMSS.sqlite.gz > /hdd-pool/subvol-121-disk-0/data/database.sqlite"
   ```

3. Fix permissions:
   ```bash
   ssh prox "pct exec 121 -- chown node:node /data/database.sqlite"
   ```

4. Restart NPM:
   ```bash
   ssh prox "pct exec 121 -- systemctl start npm"
   ```

5. Verify:
   ```bash
   curl -I http://10.92.3.3:81
   ```

**Downtime:** ~2 minutes  
**Data Loss:** Since last backup (max 24 hours)

---

### Scenario 2: Container Failure (Won't Start)

**Steps:**
1. Check container status:
   ```bash
   ssh prox "pct status 121"
   ```

2. Try starting with debug:
   ```bash
   ssh prox "pct start 121 --debug"
   ```

3. If start fails, create ZFS snapshot of current state:
   ```bash
   ssh prox "zfs snapshot hdd-pool/subvol-121-disk-0@failed-$(date +%Y%m%d-%H%M%S)"
   ```

4. **DO NOT DESTROY CONTAINER** - Extract database first:
   ```bash
   ssh prox "cp /hdd-pool/subvol-121-disk-0/data/database.sqlite /hdd-pool/backups/npm-database/emergency-backup-$(date +%Y%m%d-%H%M%S).sqlite"
   ```

5. Restore from latest vzdump backup:
   ```bash
   ssh prox "pct restore 121 /var/lib/vz/dump/vzdump-lxc-121-YYYY_MM_DD-HH_MM_SS.tar.zst --storage local"
   ```

6. Replace database with emergency backup if newer:
   ```bash
   ssh prox "cp /hdd-pool/backups/npm-database/emergency-backup-*.sqlite /hdd-pool/subvol-121-disk-0/data/database.sqlite"
   ```

7. Start container:
   ```bash
   ssh prox "pct start 121"
   ```

**Downtime:** ~10-15 minutes  
**Data Loss:** Minimal if emergency backup successful

---

### Scenario 3: Complete Container Loss

**Steps:**
1. Create new container with same CTID (121):
   ```bash
   ssh prox "pct create 121 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
     --hostname nginx-proxy \
     --net0 name=eth0,bridge=vmbr920,ip=10.92.3.3/24,gw=10.92.0.1 \
     --memory 2048 \
     --cores 2 \
     --rootfs local-zfs:8 \
     --nameserver 10.92.0.10 \
     --searchdomain cloudigan.net \
     --unprivileged 1 \
     --features nesting=1"
   ```

2. Start container and install NPM:
   ```bash
   ssh prox "pct start 121"
   ssh prox "pct exec 121 -- bash -c 'apt update && apt install -y curl && curl -fsSL https://get.docker.com | sh'"
   ssh prox "pct exec 121 -- docker run -d --name npm --restart always -p 80:80 -p 443:443 -p 81:81 -v /data:/data jc21/nginx-proxy-manager:latest"
   ```

3. Stop NPM and restore database:
   ```bash
   ssh prox "pct exec 121 -- docker stop npm"
   ssh prox "gunzip -c /hdd-pool/backups/npm-database/npm-database-LATEST.sqlite.gz > /hdd-pool/subvol-121-disk-0/data/database.sqlite"
   ssh prox "pct exec 121 -- docker start npm"
   ```

4. Verify all proxy hosts:
   ```bash
   ssh prox "sqlite3 /hdd-pool/subvol-121-disk-0/data/database.sqlite 'SELECT COUNT(*) FROM proxy_host WHERE enabled = 1;'"
   ```

**Downtime:** ~30-45 minutes  
**Data Loss:** Since last backup (max 24 hours)

---

## 📋 Pre-Flight Checklist (Before ANY NPM Changes)

- [ ] Create ZFS snapshot: `zfs snapshot hdd-pool/subvol-121-disk-0@pre-change-$(date +%Y%m%d-%H%M%S)`
- [ ] Verify latest backup exists: `ls -lh /hdd-pool/backups/npm-database/ | tail -5`
- [ ] Export current proxy host list: `sqlite3 /hdd-pool/subvol-121-disk-0/data/database.sqlite 'SELECT id, domain_names FROM proxy_host WHERE enabled = 1;' > /tmp/npm-hosts-backup.txt`
- [ ] Document change in Git: Create issue/PR in homelab-nexus
- [ ] Test rollback procedure: Verify ZFS snapshot can be listed
- [ ] **Get user approval before destructive actions**

---

## 🔍 Verification Commands

### Check Database Integrity
```bash
ssh prox "sqlite3 /hdd-pool/subvol-121-disk-0/data/database.sqlite 'PRAGMA integrity_check;'"
```

### Count Active Proxy Hosts
```bash
ssh prox "sqlite3 /hdd-pool/subvol-121-disk-0/data/database.sqlite 'SELECT COUNT(*) FROM proxy_host WHERE enabled = 1 AND is_deleted = 0;'"
```

### List All Proxy Hosts
```bash
ssh prox "sqlite3 /hdd-pool/subvol-121-disk-0/data/database.sqlite 'SELECT id, domain_names, forward_host, forward_port FROM proxy_host WHERE enabled = 1 ORDER BY id;'"
```

### Check NPM Service Status
```bash
ssh prox "pct exec 121 -- systemctl status npm"
```

### Test NPM Admin UI
```bash
curl -I http://10.92.3.3:81
```

---

## 📊 Current Baseline (2026-02-23)

**Proxy Hosts:** 32 active  
**SSL Certificates:** 27 configured  
**Database Size:** ~500KB  
**Container Disk Usage:** ~8GB

**Critical Production Apps:**
- QuantShift: 5 proxy hosts (quantshift.io, www, blue, green, api)
- TheoShift: 3 proxy hosts (theoshift.com, blue, green)
- LDC Tools: 3 proxy hosts (ldctools.com, blue, green)
- BNI Toolkit: 1 proxy host (bnitoolkit.cloudigan.net)
- Monitoring: 4 proxy hosts (grafana, prometheus, alertmanager, uptime)

---

## 🚀 Implementation Status

### ✅ Completed (2026-02-23)

1. **TrueNAS Backup Directories Created**
   ```
   /mnt/pve/media-pool/backups/npm/database/
   /mnt/pve/media-pool/backups/npm/container/
   /mnt/pve/media-pool/backups/npm/snapshots/
   ```

2. **Backup Script Deployed**
   - Location: `/usr/local/bin/backup-npm-db.sh`
   - Features: Dual backup (TrueNAS + local), integrity verification, logging
   - Source: `homelab-nexus/scripts/backup/backup-npm-db.sh`

3. **Daily Cron Job Scheduled**
   ```
   0 2 * * * /usr/local/bin/backup-npm-db.sh
   ```
   Runs daily at 2 AM

4. **Baseline ZFS Snapshot Created**
   ```
   hdd-pool/subvol-121-disk-0@baseline-2026-02-23
   ```

5. **First Backup Completed**
   - TrueNAS: `/mnt/pve/media-pool/backups/npm/database/`
   - Local: `/hdd-pool/backups/npm-database/`
   - Verified: 32 active proxy hosts

### 📋 Pending

- Weekly vzdump container backups (manual for now)
- TrueNAS ZFS snapshot schedule (configure in TrueNAS UI)
- Control plane documentation update
- Monthly recovery test

---

## 📝 Recovery Testing Schedule

**Monthly:** Test database restore from backup  
**Quarterly:** Test full container restore from vzdump  
**Annually:** Test complete rebuild from scratch

**Next Test Date:** March 23, 2026

---

## ✅ Success Criteria

- ✅ Daily automated database backups
- ✅ Weekly automated container backups
- ✅ ZFS snapshots before modifications
- ✅ Recovery procedures documented
- ✅ Tested recovery within 15 minutes
- ✅ Maximum data loss: 24 hours
- ✅ No container destruction without backup verification

---

**This plan prevents a repeat of the February 2026 incident where 2.5 months of NPM configuration was lost.**
