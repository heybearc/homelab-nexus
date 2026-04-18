# CT150 Disk Expansion

**Date:** 2026-04-18  
**Container:** CT150 (monitoring-stack)  
**Action:** Disk expansion + cleanup + log rotation configuration  
**Status:** ✅ COMPLETED

---

## Problem

CT150 was at 76% disk usage (23GB used / 32GB total), approaching the 80% warning threshold for LowDiskSpace alerts.

**Breakdown:**
- Total: 32GB
- Used: 23GB (76%)
- Free: 7.2GB

**Top consumers:**
- `/var/lib/prometheus`: 15GB (Prometheus TSDB)
- `/var/log/journal`: 2.5GB (systemd journal logs)

---

## Actions Taken

### 1. Disk Expansion (32GB → 64GB)

```bash
ssh prox "pct resize 150 rootfs +32G"
```

**Result:**
```
Size of logical volume pve/vm-150-disk-0 changed from 32.00 GiB to 64.00 GiB
Filesystem on /dev/pve/vm-150-disk-0 is now 16777216 (4k) blocks long
```

**Verification:**
```bash
# Before
Filesystem                        Size  Used Avail Use% Mounted on
/dev/mapper/pve-vm--150--disk--0   32G   23G  7.2G  76% /

# After
Filesystem                        Size  Used Avail Use% Mounted on
/dev/mapper/pve-vm--150--disk--0   63G   23G   38G  38% /
```

✅ **Disk expanded successfully** - No container restart required (online resize)

---

### 2. Journal Log Cleanup

```bash
ssh prox "pct exec 150 -- journalctl --vacuum-time=7d"
```

**Result:**
- Deleted 78 archived journal files
- **Freed 2.0GB** of disk space
- Journal size reduced from 2.5GB → 395MB

**Before/After:**
```
Before: /var/log/journal: 2.5GB
After:  /var/log/journal: 395MB
Saved:  2.1GB
```

---

### 3. APT Cache Cleanup

```bash
ssh prox "pct exec 150 -- apt-get clean"
```

**Result:**
- Cleaned package cache
- Additional space freed

---

### 4. Journal Log Rotation Configuration

**File:** `/etc/systemd/journald.conf` (CT150)

**Added configuration:**
```ini
# Limit journal disk usage
SystemMaxUse=1G
SystemKeepFree=2G
MaxRetentionSec=7d
```

**Settings:**
- `SystemMaxUse=1G` - Limit journal to 1GB total
- `SystemKeepFree=2G` - Keep 2GB free on filesystem
- `MaxRetentionSec=7d` - Keep logs for 7 days maximum

**Applied:**
```bash
ssh prox "pct exec 150 -- systemctl restart systemd-journald"
```

✅ **Journal rotation configured** - Logs will auto-cleanup after 7 days

---

## Final Results

### Disk Usage Summary

**Before:**
```
Total: 32GB
Used:  23GB (76%)
Free:  7.2GB
```

**After:**
```
Total: 63GB
Used:  20GB (33%)
Free:  41GB
```

**Improvements:**
- ✅ Disk size doubled (32GB → 64GB)
- ✅ Usage reduced by 3GB (23GB → 20GB)
- ✅ Free space increased 5.7x (7.2GB → 41GB)
- ✅ Usage percentage dropped from 76% → 33%
- ✅ No longer approaching alert threshold (80%)

---

## Space Breakdown (After Cleanup)

```
/var/lib/prometheus: 15GB (Prometheus TSDB - unchanged)
/var/log/journal:    395MB (reduced from 2.5GB)
/usr:                3.0GB
/opt:                700MB
/var/cache:          ~200MB (cleaned)
/root:               283MB
/tmp:                171MB
Other:               <100MB
```

---

## Monitoring

### Prometheus Query

Current disk usage can be monitored with:
```promql
100 - (node_filesystem_avail_bytes{instance="10.92.3.2:9100",mountpoint="/"} / node_filesystem_size_bytes{instance="10.92.3.2:9100",mountpoint="/"} * 100)
```

**Current value:** 33%

### Alert Thresholds

- **Warning:** 80% (LowDiskSpace)
- **Critical:** 90% (CriticalDiskSpace)
- **Current:** 33% ✅

**Headroom:** 47% until warning threshold

---

## Future Considerations

### Prometheus Data Retention

Currently Prometheus has **unlimited retention**, which is why `/var/lib/prometheus` is 15GB.

**Recommendation:** Set retention to 30 days

**How to implement:**
1. Edit Prometheus systemd service
2. Add flag: `--storage.tsdb.retention.time=30d`
3. Restart Prometheus

**Expected savings:** Could reduce from 15GB to ~8GB

**File to edit:** `/etc/systemd/system/prometheus.service` (CT150)

---

## Verification Commands

```bash
# Check disk usage
ssh prox "pct exec 150 -- df -h /"

# Check Prometheus data size
ssh prox "pct exec 150 -- du -sh /var/lib/prometheus"

# Check journal size
ssh prox "pct exec 150 -- du -sh /var/log/journal"

# Check journal config
ssh prox "pct exec 150 -- cat /etc/systemd/journald.conf | grep -A 3 'Limit journal'"

# Check Prometheus metrics
ssh prox "pct exec 150 -- curl -s 'http://localhost:9090/api/v1/query?query=100%20-%20(node_filesystem_avail_bytes%7Binstance%3D%2210.92.3.2%3A9100%22%2Cmountpoint%3D%22%2F%22%7D%20%2F%20node_filesystem_size_bytes%7Binstance%3D%2210.92.3.2%3A9100%22%2Cmountpoint%3D%22%2F%22%7D%20*%20100)' | jq -r '.data.result[0].value[1]'"
```

---

## Related Changes

- **Alertmanager email template** - Improved April 18, 2026 (includes disk space remediation steps)
- **Backup monitoring** - Grafana dashboard deployed April 18, 2026
- **Alert rules audit** - All 26 alerts verified April 18, 2026

---

## Summary

✅ **Disk expanded** from 32GB → 64GB (online, no downtime)  
✅ **Space cleaned** - 2GB freed from journal logs  
✅ **Log rotation configured** - Automatic cleanup after 7 days  
✅ **Usage reduced** from 76% → 33%  
✅ **Free space increased** from 7.2GB → 41GB  
✅ **Alert threshold** - 47% headroom until warning (80%)  
✅ **Future-proofed** - Journal won't grow beyond 1GB

**No further action required** - CT150 now has plenty of space for growth.

---

**Completed:** April 18, 2026 at 07:21 EDT  
**Duration:** ~5 minutes  
**Downtime:** None (online resize)
