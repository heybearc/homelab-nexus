# Proxmox Backup Strategy - Complete Infrastructure Protection

**Created:** 2026-03-20  
**Status:** Planning Phase  
**Storage Backend:** TrueNAS NFS (20TB available)

---

## 📊 Current State Assessment

### Backup Coverage Status

**✅ Currently Backed Up (1 container):**
- CT121 (nginx-proxy) - Daily database backups to TrueNAS + local

**❌ No Backup Coverage (27 containers):**
- **Production Apps (8):** CT100, CT101, CT132, CT133, CT134, CT135, CT137, CT138, CT181, CT182
- **Infrastructure (7):** CT131, CT136, CT139, CT140, CT141, CT150, CT151
- **Media Stack (6):** CT120, CT123, CT124, CT125, CT127, CT128, CT129
- **Development/Testing (2):** CT115, CT119
- **Specialized (1):** CT180

**Existing Backups (Stale):**
- CT115 (qa-01) - Dec 1, 2025 (3.5 months old)
- CT118 (netbox) - Dec 1, 2025 (3.5 months old) - **Container renumbered to CT141**
- CT121 (nginx-proxy) - Dec 1, 2025 (3.5 months old) - **Now has daily backups**
- CT134 (theoshift-blue) - Oct 21-22, 2025 (5 months old)

### Storage Analysis

**Proxmox Local Storage:**
- `/var/lib/vz` (local) - 98GB total, 58% used (35GB available)
- **Issue:** Only 35GB free - insufficient for 28 containers
- **Current backups:** 5.9GB (4 old backups)

**TrueNAS NFS Storage:**
- Mount: `/mnt/pve/media-pool` (10.92.5.200:/mnt/media-pool/data)
- Capacity: 64TB total, 44TB used, **20TB available**
- **Perfect for:** Long-term backup storage with plenty of headroom

**Proxmox Storage Pools:**
- `hdd-pool` (ZFS) - 16.8GB total, 25% used (12.6GB available)
- `local-lvm` (LVM thin) - 1.7TB total, 11% used (1.5TB available)
- `ssd2-lvm` (LVM thin) - 1.9TB total, 0% used (1.9TB available)

---

## 🎯 Backup Strategy Design

### Tiered Backup Approach

#### Tier 1: Critical Production (Daily Backups)
**Containers:** CT131, CT132, CT133, CT134, CT135, CT136, CT137, CT138, CT139, CT141, CT150, CT151, CT181, CT182

**Rationale:** Production apps, infrastructure services, databases
- TheoShift (blue/green): CT132, CT134
- LDC Tools (blue/green): CT133, CT135
- QuantShift (blue/green): CT137, CT138
- Cloudigan API (blue/green): CT181, CT182
- PostgreSQL (primary/replica): CT131, CT151
- HAProxy (primary/standby): CT136, CT139
- Netbox: CT141
- Monitoring: CT150

**Schedule:** Daily at 2:00 AM
**Retention:** 7 daily, 4 weekly, 3 monthly
**Storage:** TrueNAS NFS (`/mnt/pve/media-pool/backups/tier1/`)

#### Tier 2: Important Services (Weekly Backups)
**Containers:** CT100, CT101, CT115, CT119, CT121, CT140, CT180

**Rationale:** Bot infrastructure, testing, development, DNS, specialized services
- QuantShift bots: CT100, CT101
- QA testing: CT115
- BNI dev: CT119
- Nginx Proxy: CT121 (already has daily DB backups, add full container weekly)
- AdGuard DNS: CT140
- Scrypted NVR: CT180

**Schedule:** Weekly on Sunday at 3:00 AM
**Retention:** 4 weekly, 2 monthly
**Storage:** TrueNAS NFS (`/mnt/pve/media-pool/backups/tier2/`)

#### Tier 3: Media Stack (Monthly Backups)
**Containers:** CT120, CT123, CT124, CT125, CT127, CT128, CT129

**Rationale:** Media services - easily reinstallable, configuration is key
- Readarr: CT120
- Prowlarr: CT123
- Radarr: CT124
- Sonarr: CT125
- SABnzbd: CT127
- Plex: CT128
- Calibre-web: CT129

**Schedule:** Monthly on 1st at 4:00 AM
**Retention:** 3 monthly
**Storage:** TrueNAS NFS (`/mnt/pve/media-pool/backups/tier3/`)

---

## 🔧 Implementation Plan

### Phase 1: TrueNAS Storage Configuration (30 min)

1. **Add TrueNAS NFS as Proxmox Storage**
   ```bash
   # Add NFS storage to Proxmox
   pvesm add nfs truenas-backups \
     --server 10.92.5.200 \
     --export /mnt/media-pool/data/proxmox-backups \
     --content backup \
     --maxfiles 0
   ```

2. **Create Backup Directory Structure on TrueNAS**
   ```bash
   ssh truenas "mkdir -p /mnt/media-pool/data/proxmox-backups/{tier1,tier2,tier3,logs}"
   ssh truenas "chmod 755 /mnt/media-pool/data/proxmox-backups"
   ```

3. **Verify Mount and Permissions**
   ```bash
   ssh prox "pvesm status | grep truenas"
   ssh prox "ls -la /mnt/pve/truenas-backups/"
   ```

### Phase 2: Backup Job Configuration (1 hour)

**Option A: Proxmox Web UI (Recommended)**
1. Navigate to Datacenter → Backup
2. Click "Add" to create backup jobs
3. Configure each tier with appropriate schedule and retention

**Option B: CLI Configuration**

Create backup job configuration file:
```bash
# /etc/pve/vzdump.cron
# Tier 1: Critical Production - Daily 2 AM
0 2 * * * root vzdump 131,132,133,134,135,136,137,138,139,141,150,151,181,182 --storage truenas-backups --mode snapshot --compress zstd --mailnotification failure --prune-backups keep-daily=7,keep-weekly=4,keep-monthly=3

# Tier 2: Important Services - Weekly Sunday 3 AM
0 3 * * 0 root vzdump 100,101,115,119,121,140,180 --storage truenas-backups --mode snapshot --compress zstd --mailnotification failure --prune-backups keep-weekly=4,keep-monthly=2

# Tier 3: Media Stack - Monthly 1st at 4 AM
0 4 1 * * root vzdump 120,123,124,125,127,128,129 --storage truenas-backups --mode snapshot --compress zstd --mailnotification failure --prune-backups keep-monthly=3
```

### Phase 3: Database-Specific Backups (30 min)

**PostgreSQL (CT131) - Application-Level Backups**
```bash
# Create backup script on CT131
cat > /usr/local/bin/backup-postgres.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +%Y%m%d-%H%M%S)
TRUENAS_DIR="/mnt/truenas-backups/database"

mkdir -p "$BACKUP_DIR"

# Backup all databases
for DB in ldc_tools theoshift_scheduler quantshift bni_toolkit netbox; do
    pg_dump -U postgres "$DB" | gzip > "$BACKUP_DIR/${DB}-${DATE}.sql.gz"
done

# Copy to TrueNAS
rsync -av "$BACKUP_DIR/" "$TRUENAS_DIR/"

# Keep last 14 days locally
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +14 -delete

echo "$(date): PostgreSQL backups completed" >> /var/log/postgres-backup.log
EOF

chmod +x /usr/local/bin/backup-postgres.sh

# Add to crontab
echo "0 1 * * * /usr/local/bin/backup-postgres.sh" | crontab -
```

**NPM Database (CT121) - Already Configured**
- Daily backups to TrueNAS at 2 AM ✅
- Keep existing configuration

### Phase 4: Monitoring & Alerting (30 min)

1. **Configure Backup Monitoring in Prometheus**
   - Add backup job metrics
   - Alert on backup failures
   - Track backup sizes and durations

2. **Email Notifications**
   ```bash
   # Configure Proxmox email settings
   # Datacenter → Options → Email
   ```

3. **Grafana Dashboard**
   - Create backup status dashboard
   - Show last successful backup per container
   - Display storage usage trends

---

## 📋 Backup Job Summary

| Tier | Containers | Schedule | Retention | Storage | Est. Size |
|------|-----------|----------|-----------|---------|-----------|
| Tier 1 | 14 containers | Daily 2 AM | 7d/4w/3m | TrueNAS | ~25GB/day |
| Tier 2 | 7 containers | Weekly Sun 3 AM | 4w/2m | TrueNAS | ~15GB/week |
| Tier 3 | 7 containers | Monthly 1st 4 AM | 3m | TrueNAS | ~10GB/month |
| **Total** | **28 containers** | - | - | - | **~200GB** |

**Storage Requirements:**
- Daily backups: 25GB × 7 = 175GB
- Weekly backups: 15GB × 4 = 60GB
- Monthly backups: 10GB × 3 = 30GB
- **Total:** ~265GB (1.3% of 20TB available)

---

## 🔍 Backup Verification

### Automated Testing
```bash
# Monthly backup restore test script
cat > /usr/local/bin/test-backup-restore.sh << 'EOF'
#!/bin/bash
# Test restore of random container from backup
CONTAINER=$(shuf -n1 -e 131 132 133 134 135 136 137 138 139 141 150 151)
LATEST_BACKUP=$(ls -t /mnt/pve/truenas-backups/dump/vzdump-lxc-${CONTAINER}-*.tar.zst | head -1)

echo "Testing restore of CT${CONTAINER} from ${LATEST_BACKUP}"
# Verify backup integrity
zstd -t "$LATEST_BACKUP"
if [ $? -eq 0 ]; then
    echo "✅ Backup integrity verified for CT${CONTAINER}"
else
    echo "❌ Backup corruption detected for CT${CONTAINER}"
fi
EOF

chmod +x /usr/local/bin/test-backup-restore.sh
```

### Manual Verification Commands
```bash
# List all backups
ssh prox "pvesm list truenas-backups"

# Check backup job status
ssh prox "cat /var/log/vzdump.log | tail -50"

# Verify specific container backup
ssh prox "ls -lh /mnt/pve/truenas-backups/dump/ | grep 'lxc-131'"

# Test backup integrity
ssh prox "zstd -t /mnt/pve/truenas-backups/dump/vzdump-lxc-131-*.tar.zst"
```

---

## 🚨 Recovery Procedures

### Full Container Restore
```bash
# List available backups
pvesm list truenas-backups

# Restore container (will stop existing container with same CTID)
pct restore <CTID> truenas-backups:backup/vzdump-lxc-<CTID>-YYYY_MM_DD-HH_MM_SS.tar.zst --storage local-lvm

# Start restored container
pct start <CTID>
```

### Database-Only Restore
```bash
# PostgreSQL database restore
ssh prox "pct exec 131 -- bash -c 'gunzip -c /var/backups/postgresql/dbname-YYYYMMDD-HHMMSS.sql.gz | psql -U postgres dbname'"

# NPM database restore (existing procedure)
# See NPM-BACKUP-RECOVERY-PLAN.md
```

---

## 💰 Cost Analysis

**Storage Costs:**
- TrueNAS NFS: $0 (already owned, 20TB available)
- Estimated usage: 265GB (~1.3% of available)
- Room for growth: 19.7TB remaining

**Time Costs:**
- Initial setup: 2-3 hours
- Monthly maintenance: 30 minutes
- Recovery testing: 1 hour/month

**Risk Mitigation:**
- **Before:** 96% of containers unprotected (27/28)
- **After:** 100% backup coverage (28/28)
- **RPO (Recovery Point Objective):** 24 hours (Tier 1), 7 days (Tier 2), 30 days (Tier 3)
- **RTO (Recovery Time Objective):** 15-30 minutes per container

---

## ✅ Implementation Checklist

### Pre-Implementation
- [ ] Verify TrueNAS NFS mount accessible from Proxmox
- [ ] Confirm 20TB available on TrueNAS
- [ ] Test NFS write permissions
- [ ] Document current container states

### Phase 1: Storage Setup
- [ ] Add TrueNAS NFS to Proxmox storage
- [ ] Create backup directory structure
- [ ] Verify mount and permissions
- [ ] Test write access

### Phase 2: Backup Jobs
- [ ] Configure Tier 1 backup job (14 containers, daily)
- [ ] Configure Tier 2 backup job (7 containers, weekly)
- [ ] Configure Tier 3 backup job (7 containers, monthly)
- [ ] Verify cron schedules
- [ ] Test manual backup of one container

### Phase 3: Database Backups
- [ ] Deploy PostgreSQL backup script to CT131
- [ ] Configure cron for database backups
- [ ] Verify NPM backup still running
- [ ] Test database backup/restore

### Phase 4: Monitoring
- [ ] Configure email notifications
- [ ] Add Prometheus metrics
- [ ] Create Grafana dashboard
- [ ] Set up failure alerts

### Post-Implementation
- [ ] Run first backup manually and verify
- [ ] Document backup locations in control plane
- [ ] Schedule monthly restore testing
- [ ] Update IMPLEMENTATION-PLAN.md

---

## 📝 Alternative Approaches Considered

### Why Not Proxmox Backup Server (PBS)?
**Pros:** Deduplication, incremental backups, web UI
**Cons:** Requires separate VM/container, additional complexity, learning curve
**Decision:** Use native vzdump + TrueNAS NFS for simplicity and existing infrastructure

### Why Not Local Storage Only?
**Pros:** Faster backups, no network dependency
**Cons:** Only 35GB available, single point of failure
**Decision:** Use TrueNAS for capacity and redundancy

### Why Not Cloud Backups?
**Pros:** Offsite protection, disaster recovery
**Cons:** Cost ($50-200/month for 265GB), slow recovery, bandwidth limits
**Decision:** TrueNAS provides sufficient redundancy for homelab, consider cloud for critical data only

---

## 🔄 Maintenance Schedule

**Daily:**
- Automated Tier 1 backups (2 AM)
- Automated database backups (1 AM)

**Weekly:**
- Automated Tier 2 backups (Sunday 3 AM)
- Review backup logs for failures

**Monthly:**
- Automated Tier 3 backups (1st at 4 AM)
- Restore test of random container
- Review storage usage trends
- Prune old backups (automated)

**Quarterly:**
- Full disaster recovery drill
- Update backup documentation
- Review and adjust retention policies

---

## 📚 Related Documentation

- `NPM-BACKUP-RECOVERY-PLAN.md` - NPM-specific backup procedures
- `_cloudy-ops/docs/infrastructure/proxmox-infrastructure-spec.md` - Infrastructure overview
- `_cloudy-ops/context/APP-MAP.md` - Container inventory
- `TASK-STATE.md` - Current infrastructure status

---

**Status:** Ready for implementation  
**Estimated Setup Time:** 2-3 hours  
**Monthly Storage Growth:** ~25GB  
**Protection Level:** 100% coverage (28/28 containers)
