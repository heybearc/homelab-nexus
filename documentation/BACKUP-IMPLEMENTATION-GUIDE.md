# Proxmox Backup Implementation Guide

**Date:** 2026-03-20  
**Objective:** Implement automated backups for all 28 containers using TrueNAS NFS storage  
**Estimated Time:** 2-3 hours  
**Prerequisites:** TrueNAS accessible, 20TB available storage

---

## 🎯 Quick Summary

**Current State:**
- 27/28 containers have NO backup coverage
- Only CT121 (nginx-proxy) has daily backups
- 20TB available on TrueNAS NFS

**Target State:**
- 100% backup coverage (28/28 containers)
- Tiered backup strategy (daily/weekly/monthly)
- Automated retention and pruning
- Monitoring and alerting

---

## 📋 Implementation Steps

### Step 1: Verify TrueNAS NFS Access (5 min)

```bash
# Check current TrueNAS mount
ssh prox "df -h /mnt/pve/media-pool"

# Expected output: 64T total, ~20T available
```

**Verify NFS is working:**
```bash
ssh prox "touch /mnt/pve/media-pool/test-write && rm /mnt/pve/media-pool/test-write && echo 'NFS write OK'"
```

### Step 2: Create Backup Directory on TrueNAS (10 min)

```bash
# SSH to TrueNAS and create directory structure
ssh truenas << 'EOF'
mkdir -p /mnt/media-pool/data/proxmox-backups/{tier1,tier2,tier3,database,logs}
chmod 755 /mnt/media-pool/data/proxmox-backups
chown -R root:root /mnt/media-pool/data/proxmox-backups
ls -la /mnt/media-pool/data/proxmox-backups/
EOF
```

**Expected output:**
```
drwxr-xr-x  7 root  root   7 Mar 20 14:00 .
drwxr-xr-x  5 root  root   5 Mar 20 14:00 ..
drwxr-xr-x  2 root  root   2 Mar 20 14:00 database
drwxr-xr-x  2 root  root   2 Mar 20 14:00 logs
drwxr-xr-x  2 root  root   2 Mar 20 14:00 tier1
drwxr-xr-x  2 root  root   2 Mar 20 14:00 tier2
drwxr-xr-x  2 root  root   2 Mar 20 14:00 tier3
```

### Step 3: Add TrueNAS Storage to Proxmox (10 min)

**Option A: Web UI (Recommended)**

1. Open Proxmox web UI: https://10.92.0.5:8006
2. Navigate to: **Datacenter → Storage → Add → NFS**
3. Configure:
   - **ID:** `truenas-backups`
   - **Server:** `10.92.5.200`
   - **Export:** `/mnt/media-pool/data/proxmox-backups`
   - **Content:** `VZDump backup file` (check only this)
   - **Nodes:** `prox` (or leave blank for all nodes)
   - **Enable:** ✓ (checked)
   - **Max Backups:** `0` (unlimited, we'll use prune-backups instead)
4. Click **Add**

**Option B: CLI**

```bash
ssh prox << 'EOF'
pvesm add nfs truenas-backups \
  --server 10.92.5.200 \
  --export /mnt/media-pool/data/proxmox-backups \
  --content backup \
  --maxfiles 0
EOF
```

**Verify storage added:**
```bash
ssh prox "pvesm status | grep truenas"
```

**Expected output:**
```
truenas-backups  nfs       active      20971520000  44040192000  -
```

### Step 4: Test Backup to TrueNAS (10 min)

**Test with a small container first (CT115 - qa-01):**

```bash
# Manual test backup
ssh prox "vzdump 115 --storage truenas-backups --mode snapshot --compress zstd"
```

**Verify backup created:**
```bash
ssh prox "pvesm list truenas-backups"
```

**Expected output:**
```
Volid                                                           Format  Type             Size
truenas-backups:backup/vzdump-lxc-115-2026_03_20-14_30_00.tar.zst  tar.zst backup    1073741824
```

**Check backup on TrueNAS:**
```bash
ssh truenas "ls -lh /mnt/media-pool/data/proxmox-backups/dump/"
```

### Step 5: Configure Automated Backup Jobs (30 min)

**Option A: Web UI (Recommended for beginners)**

1. Navigate to: **Datacenter → Backup**
2. Click **Add** to create new backup job

**Tier 1 Job (Critical Production - Daily):**
- **Node:** `prox`
- **Storage:** `truenas-backups`
- **Schedule:** `0 2 * * *` (Daily at 2 AM)
- **Selection mode:** `Include selected VMs`
- **VMs:** `131,132,133,134,135,136,137,138,139,141,150,151,181,182`
- **Compression:** `ZSTD`
- **Mode:** `Snapshot`
- **Enable:** ✓
- **Retention:** 
  - Keep daily: `7`
  - Keep weekly: `4`
  - Keep monthly: `3`
- **Email notification:** `failure` (or `always` if you want success emails)
- **Protected:** ☐ (unchecked)

**Tier 2 Job (Important Services - Weekly):**
- **Node:** `prox`
- **Storage:** `truenas-backups`
- **Schedule:** `0 3 * * 0` (Sunday at 3 AM)
- **VMs:** `100,101,115,119,121,140,180`
- **Compression:** `ZSTD`
- **Mode:** `Snapshot`
- **Retention:**
  - Keep weekly: `4`
  - Keep monthly: `2`

**Tier 3 Job (Media Stack - Monthly):**
- **Node:** `prox`
- **Storage:** `truenas-backups`
- **Schedule:** `0 4 1 * *` (1st of month at 4 AM)
- **VMs:** `120,123,124,125,127,128,129`
- **Compression:** `ZSTD`
- **Mode:** `Snapshot`
- **Retention:**
  - Keep monthly: `3`

**Option B: CLI (Advanced)**

```bash
# Edit vzdump cron configuration
ssh prox "cat > /etc/pve/vzdump.cron << 'EOF'
# cluster wide vzdump cron schedule
# Automatically generated file - do not edit

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

# Tier 1: Critical Production - Daily at 2 AM
0 2 * * * root vzdump 131,132,133,134,135,136,137,138,139,141,150,151,181,182 --storage truenas-backups --mode snapshot --compress zstd --mailnotification failure --prune-backups keep-daily=7,keep-weekly=4,keep-monthly=3

# Tier 2: Important Services - Weekly Sunday at 3 AM
0 3 * * 0 root vzdump 100,101,115,119,121,140,180 --storage truenas-backups --mode snapshot --compress zstd --mailnotification failure --prune-backups keep-weekly=4,keep-monthly=2

# Tier 3: Media Stack - Monthly 1st at 4 AM
0 4 1 * * root vzdump 120,123,124,125,127,128,129 --storage truenas-backups --mode snapshot --compress zstd --mailnotification failure --prune-backups keep-monthly=3
EOF"
```

**Verify cron configuration:**
```bash
ssh prox "cat /etc/pve/vzdump.cron"
```

### Step 6: Configure PostgreSQL Database Backups (20 min)

**Create backup script on PostgreSQL container (CT131):**

```bash
ssh prox "pct exec 131 -- bash -c 'cat > /usr/local/bin/backup-postgres.sh << \"SCRIPT\"
#!/bin/bash
# PostgreSQL Database Backup Script
# Runs daily at 1 AM (before container backups)

BACKUP_DIR=\"/var/backups/postgresql\"
DATE=\$(date +%Y%m%d-%H%M%S)
TRUENAS_MOUNT=\"/mnt/truenas-backups\"

# Create local backup directory
mkdir -p \"\$BACKUP_DIR\"

# Backup each database
for DB in ldc_tools theoshift_scheduler quantshift bni_toolkit netbox; do
    echo \"Backing up \$DB...\"
    pg_dump -U postgres \"\$DB\" | gzip > \"\$BACKUP_DIR/\${DB}-\${DATE}.sql.gz\"
    
    if [ \$? -eq 0 ]; then
        echo \"✅ \$DB backup successful\"
    else
        echo \"❌ \$DB backup failed\"
    fi
done

# Copy to TrueNAS if mounted
if [ -d \"\$TRUENAS_MOUNT/database\" ]; then
    cp -v \"\$BACKUP_DIR\"/*.sql.gz \"\$TRUENAS_MOUNT/database/\"
    echo \"✅ Backups copied to TrueNAS\"
else
    echo \"⚠️  TrueNAS mount not available, backups stored locally only\"
fi

# Keep last 14 days locally
find \"\$BACKUP_DIR\" -name \"*.sql.gz\" -mtime +14 -delete

# Log completion
echo \"\$(date): PostgreSQL backups completed\" >> /var/log/postgres-backup.log
SCRIPT
'"
```

**Make script executable:**
```bash
ssh prox "pct exec 131 -- chmod +x /usr/local/bin/backup-postgres.sh"
```

**Mount TrueNAS backup directory in PostgreSQL container:**
```bash
# Add bind mount to container config
ssh prox "cat >> /etc/pve/lxc/131.conf << 'EOF'
mp0: /mnt/pve/media-pool/proxmox-backups,mp=/mnt/truenas-backups
EOF"

# Restart container to apply mount
ssh prox "pct stop 131 && sleep 5 && pct start 131"

# Verify mount
ssh prox "pct exec 131 -- df -h /mnt/truenas-backups"
```

**Add to crontab:**
```bash
ssh prox "pct exec 131 -- bash -c '(crontab -l 2>/dev/null; echo \"0 1 * * * /usr/local/bin/backup-postgres.sh\") | crontab -'"

# Verify crontab
ssh prox "pct exec 131 -- crontab -l"
```

**Test database backup manually:**
```bash
ssh prox "pct exec 131 -- /usr/local/bin/backup-postgres.sh"

# Verify backups created
ssh prox "pct exec 131 -- ls -lh /var/backups/postgresql/"
ssh truenas "ls -lh /mnt/media-pool/data/proxmox-backups/database/"
```

### Step 7: Configure Email Notifications (15 min)

**Configure Proxmox email settings:**

1. Navigate to: **Datacenter → Options**
2. Double-click **Email from address**
3. Set: `proxmox@cloudigan.net` (or your email)
4. Click **OK**

**Test email notifications:**
```bash
ssh prox "echo 'Test backup notification' | mail -s 'Proxmox Backup Test' your-email@example.com"
```

### Step 8: Create Monitoring Dashboard (30 min)

**Add backup metrics to Prometheus (on CT150):**

```bash
# Create backup monitoring script
ssh prox "pct exec 150 -- bash -c 'cat > /opt/monitoring/backup-metrics.sh << \"SCRIPT\"
#!/bin/bash
# Backup Monitoring Metrics for Prometheus

METRICS_FILE=\"/var/lib/node_exporter/textfile_collector/backup_metrics.prom\"
mkdir -p /var/lib/node_exporter/textfile_collector

# Get last backup time for each container
for CTID in 100 101 115 119 120 121 123 124 125 127 128 129 131 132 133 134 135 136 137 138 139 140 141 150 151 180 181 182; do
    LAST_BACKUP=\$(ssh prox \"pvesm list truenas-backups | grep lxc-\${CTID}- | tail -1 | awk '{print \\\$1}'\" 2>/dev/null)
    
    if [ -n \"\$LAST_BACKUP\" ]; then
        # Extract timestamp from backup filename
        TIMESTAMP=\$(echo \"\$LAST_BACKUP\" | grep -oP '\\d{4}_\\d{2}_\\d{2}-\\d{2}_\\d{2}_\\d{2}')
        EPOCH=\$(date -d \"\${TIMESTAMP//_/ }\" +%s 2>/dev/null || echo 0)
        echo \"proxmox_backup_last_success{ctid=\\\"\${CTID}\\\"} \$EPOCH\"
    else
        echo \"proxmox_backup_last_success{ctid=\\\"\${CTID}\\\"} 0\"
    fi
done > \"\$METRICS_FILE\"

echo \"proxmox_backup_metrics_updated \$(date +%s)\" >> \"\$METRICS_FILE\"
SCRIPT
'"

# Make executable
ssh prox "pct exec 150 -- chmod +x /opt/monitoring/backup-metrics.sh"

# Add to crontab (run every hour)
ssh prox "pct exec 150 -- bash -c '(crontab -l 2>/dev/null; echo \"0 * * * * /opt/monitoring/backup-metrics.sh\") | crontab -'"
```

**Create Grafana dashboard:**
- Navigate to Grafana: https://grafana.cloudigan.net
- Create new dashboard: "Proxmox Backups"
- Add panels for:
  - Last successful backup per container
  - Backup age (time since last backup)
  - Backup storage usage
  - Failed backup alerts

### Step 9: Verify and Test (20 min)

**Verify all backup jobs configured:**
```bash
ssh prox "cat /etc/pve/vzdump.cron"
```

**Check backup job status:**
```bash
# View recent backup logs
ssh prox "tail -100 /var/log/vzdump.log"
```

**Manually trigger Tier 1 backup (optional test):**
```bash
# Run backup job manually (don't wait for scheduled time)
ssh prox "vzdump 131 --storage truenas-backups --mode snapshot --compress zstd"
```

**Verify backup integrity:**
```bash
# Test backup file integrity
ssh prox "zstd -t /mnt/pve/truenas-backups/dump/vzdump-lxc-131-*.tar.zst"
```

**Expected output:**
```
/mnt/pve/truenas-backups/dump/vzdump-lxc-131-2026_03_20-14_30_00.tar.zst : 1234567890 bytes
```

### Step 10: Document and Update Control Plane (10 min)

**Update TASK-STATE.md:**
```bash
# Add to recent completions
- ✅ Implemented comprehensive backup strategy for all 28 containers
- ✅ Configured TrueNAS NFS storage for backups (20TB available)
- ✅ Set up tiered backup schedule (daily/weekly/monthly)
- ✅ Configured PostgreSQL database backups
- ✅ Added backup monitoring and alerting
```

**Update IMPLEMENTATION-PLAN.md:**
```bash
# Move from backlog to completed
- [x] Backup Automation for All Containers (effort: M) - Completed 2026-03-20
```

---

## ✅ Post-Implementation Checklist

- [ ] TrueNAS backup directory created and accessible
- [ ] Proxmox storage `truenas-backups` added and active
- [ ] Test backup completed successfully
- [ ] Tier 1 backup job configured (14 containers, daily)
- [ ] Tier 2 backup job configured (7 containers, weekly)
- [ ] Tier 3 backup job configured (7 containers, monthly)
- [ ] PostgreSQL database backup script deployed
- [ ] Database backup cron configured
- [ ] Email notifications configured
- [ ] Backup monitoring metrics added
- [ ] Grafana dashboard created
- [ ] Test backup restore performed
- [ ] Documentation updated

---

## 🔍 Verification Commands

**Check storage status:**
```bash
ssh prox "pvesm status | grep truenas"
```

**List all backups:**
```bash
ssh prox "pvesm list truenas-backups"
```

**Check backup job schedule:**
```bash
ssh prox "cat /etc/pve/vzdump.cron"
```

**View recent backup logs:**
```bash
ssh prox "tail -50 /var/log/vzdump.log"
```

**Check database backups:**
```bash
ssh prox "pct exec 131 -- ls -lh /var/backups/postgresql/"
ssh truenas "ls -lh /mnt/media-pool/data/proxmox-backups/database/"
```

**Verify backup integrity:**
```bash
ssh prox "zstd -t /mnt/pve/truenas-backups/dump/vzdump-lxc-*.tar.zst | head -5"
```

---

## 🚨 Troubleshooting

### Issue: NFS mount not accessible
```bash
# Check NFS mount
ssh prox "mount | grep media-pool"

# Remount if needed
ssh prox "umount /mnt/pve/media-pool && mount -a"
```

### Issue: Backup job fails with "storage not available"
```bash
# Verify storage is enabled
ssh prox "pvesm status | grep truenas"

# Check NFS connectivity
ssh prox "showmount -e 10.92.5.200"
```

### Issue: Database backup script fails
```bash
# Check PostgreSQL is running
ssh prox "pct exec 131 -- systemctl status postgresql"

# Test database connection
ssh prox "pct exec 131 -- psql -U postgres -l"

# Check TrueNAS mount in container
ssh prox "pct exec 131 -- df -h /mnt/truenas-backups"
```

### Issue: Backup takes too long
```bash
# Check backup mode (snapshot is fastest)
# Verify compression level (zstd is good balance)
# Consider excluding large temporary files
```

---

## 📊 Expected Results

**After First Night (Tier 1 runs at 2 AM):**
- 14 container backups on TrueNAS
- ~25GB storage used
- Email notification (if configured)

**After First Week (Tier 2 runs Sunday 3 AM):**
- 21 total container backups (14 daily + 7 weekly)
- ~40GB storage used

**After First Month:**
- All 28 containers backed up
- ~265GB storage used (1.3% of 20TB)
- Full backup coverage achieved

---

## 🎯 Success Criteria

✅ **100% backup coverage** - All 28 containers backed up  
✅ **Automated retention** - Old backups pruned automatically  
✅ **Monitoring enabled** - Backup status visible in Grafana  
✅ **Email alerts** - Notified of backup failures  
✅ **Tested recovery** - Verified restore procedure works  
✅ **Documentation complete** - All procedures documented

---

**Ready to implement? Start with Step 1 and work through sequentially.**
