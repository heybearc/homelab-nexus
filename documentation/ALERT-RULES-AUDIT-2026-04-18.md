# Alert Rules Audit - Email Notification Quality

**Date:** 2026-04-18  
**Status:** ✅ ALL ALERTS HAVE PROPER ANNOTATIONS  
**Email Template:** ✅ IMPROVED (April 18, 2026)

---

## Summary

Audited all Prometheus alert rules to ensure email notifications contain actionable information. **All 26 alert rules** have proper `summary` and `description` annotations that will display correctly in the improved email template.

---

## Alert Rules by Category

### Infrastructure Health (homelab.yml) - 8 alerts

| Alert Name | Severity | Summary | Description Quality |
|------------|----------|---------|-------------------|
| ContainerDown | critical | ✅ "Container {instance} is DOWN" | ✅ Includes instance and container ID |
| HighCPU | warning | ✅ "High CPU on {instance}" | ✅ Shows exact CPU % usage |
| HighMemory | warning | ✅ "High memory on {instance}" | ✅ Shows exact memory % usage |
| LowDiskSpace | warning | ✅ "Low disk on {instance}" | ✅ Shows exact disk % usage |
| CriticalDiskSpace | critical | ✅ "CRITICAL disk on {instance}" | ✅ Shows exact disk % usage |

**Email Template Actions:** ✅ Custom remediation steps for all disk/CPU/memory alerts

---

### Bot Health (homelab.yml) - 3 alerts

| Alert Name | Severity | Summary | Description Quality |
|------------|----------|---------|-------------------|
| BotContainerDown | critical | ✅ "QuantShift bot container DOWN: {instance}" | ✅ Clear bot identification |
| BotProcessDown | critical | ✅ "QuantShift bot process DOWN: {name}" | ✅ Shows service name |
| BotServiceFailed | critical | ✅ "QuantShift bot service FAILED: {name}" | ✅ Indicates failed state |

**Email Template Actions:** ⚠️ Generic template (could add bot-specific actions)

---

### PostgreSQL Health (homelab.yml) - 2 alerts

| Alert Name | Severity | Summary | Description Quality |
|------------|----------|---------|-------------------|
| PostgresDown | critical | ✅ "PostgreSQL is DOWN" | ✅ Specifies CT131 |
| PostgresTooManyConnections | warning | ✅ "PostgreSQL high connection count" | ✅ Shows connection count and limit |

**Email Template Actions:** ✅ Custom PostgreSQL restart/diagnostic commands

---

### HAProxy Health (homelab.yml) - 2 alerts

| Alert Name | Severity | Summary | Description Quality |
|------------|----------|---------|-------------------|
| HAProxyDown | critical | ✅ "HAProxy is DOWN" | ✅ Specifies CT136 |
| HAProxyBackendDown | critical | ✅ "HAProxy backend {backend} is DOWN" | ✅ Shows which backend failed |

**Email Template Actions:** ✅ Custom HAProxy stats and diagnostic commands

---

### TrueNAS Health (homelab.yml) - 6 alerts

| Alert Name | Severity | Summary | Description Quality |
|------------|----------|---------|-------------------|
| TrueNASPoolDegraded | critical | ✅ "TrueNAS pool {pool} is DEGRADED" | ✅ Explains RAIDZ1 redundancy loss |
| TrueNASDiskFaulted | critical | ✅ "TrueNAS disk FAULTED in pool {pool}" | ✅ Shows disk, vdev, pool, status |
| TrueNASDiskWriteErrors | warning | ✅ "TrueNAS disk {disk} has write errors" | ✅ Shows error count and pool |
| TrueNASDiskReadErrors | warning | ✅ "TrueNAS disk {disk} has read errors" | ✅ Shows error count and pool |
| TrueNASAppDown | warning | ✅ "TrueNAS app {app} is not running" | ✅ Shows app name and version |
| TrueNASCriticalAlert | critical | ✅ "TrueNAS has {value} critical alert(s)" | ✅ Directs to TrueNAS UI |
| TrueNASExporterDown | warning | ✅ "TrueNAS exporter is unreachable" | ✅ Explains metrics unavailable |

**Email Template Actions:** ⚠️ Generic template (could add TrueNAS-specific actions)

---

### Windows Server Health (windows-alerts.yml) - 7 alerts

| Alert Name | Severity | Summary | Description Quality |
|------------|----------|---------|-------------------|
| WindowsServerDown | critical | ✅ "Windows Server {instance} is down" | ✅ Shows downtime duration |
| WindowsHighCPU | warning | ✅ "High CPU usage on {instance}" | ✅ Shows exact CPU % |
| WindowsHighMemory | warning | ✅ "High memory usage on {instance}" | ✅ Shows exact memory % |
| WindowsLowDiskSpace | warning | ✅ "Low disk space on {instance}" | ✅ Shows volume and % free |
| TailscaleServiceDown | critical | ✅ "Tailscale service is not running on {instance}" | ✅ Shows downtime duration |
| VMToolsServiceDown | critical | ✅ "VMTools service is not running on {instance}" | ✅ Explains RDP impact |
| QEMUGuestAgentDown | critical | ✅ "QEMU Guest Agent is not running on {instance}" | ✅ Explains VM management impact |

**Email Template Actions:** ⚠️ Generic template (could add Windows-specific actions)

---

### PostgreSQL HA (postgresql-ha.yml) - 1 alert

| Alert Name | Severity | Summary | Description Quality |
|------------|----------|---------|-------------------|
| PostgreSQLPrimaryDown | critical | ✅ "PostgreSQL Primary (CT131) is down" | ✅ Mentions automatic failover to CT151 |

**Email Template Actions:** ✅ Custom PostgreSQL commands (shared with PostgresDown)

---

## Email Template Coverage

### Alerts with Custom Action Items ✅
1. **LowDiskSpace** - SSH, disk check, cleanup commands
2. **CriticalDiskSpace** - URGENT actions, immediate cleanup
3. **HighCPU** - Process monitoring, top, mpstat
4. **HighMemory** - Memory check, process list
5. **ContainerDown** - Proxmox container management
6. **PostgresDown** - Database restart, log viewing
7. **HAProxyBackendDown** - Stats page, backend health checks

### Alerts with Generic Template (Still Useful) ⚠️
- All other alerts show: summary, description, instance, severity, labels, timestamps
- Generic template still provides all necessary info for diagnosis
- Could enhance with alert-specific actions in future

---

## Current Disk Space Issue

### Identified Problem
**Container:** CT150 (monitoring-stack)  
**Current Usage:** 76% (23GB used / 32GB total)  
**Threshold:** 80% (warning), 90% (critical)  
**Status:** ⚠️ Approaching warning threshold

### Breakdown
```
Total: 32GB
Used:  23GB (76%)
Free:  7.2GB

Top Consumers:
- /var/lib/prometheus: 15GB (Prometheus TSDB)
- /var/log/journal:    2.5GB (systemd journal logs)
- /var/log/sysstat:    26MB
- /var/cache:          776MB
```

### Recommended Actions

**Immediate (if >80%):**
```bash
# Clean journal logs (keep last 7 days)
ssh prox "pct exec 150 -- journalctl --vacuum-time=7d"

# Clean apt cache
ssh prox "pct exec 150 -- apt-get clean"
```

**Long-term Solutions:**

1. **Increase Prometheus retention** (currently unlimited)
   ```bash
   # Edit Prometheus config to limit retention
   # Add: --storage.tsdb.retention.time=30d
   ```

2. **Expand CT150 disk** (32GB → 64GB)
   ```bash
   ssh prox "pct resize 150 rootfs +32G"
   ```

3. **Configure log rotation** for journal
   ```bash
   # Set SystemMaxUse in /etc/systemd/journald.conf
   SystemMaxUse=1G
   ```

---

## Prometheus Disk Usage Query

To check disk usage across all containers:

```promql
100 - (node_filesystem_avail_bytes{fstype!="tmpfs",mountpoint="/"} / node_filesystem_size_bytes{fstype!="tmpfs",mountpoint="/"} * 100)
```

**Current Results (>70% usage):**
- monitor (CT150): 77%
- haproxy (CT136): 71%
- ldc-staging (CT133): 70%

---

## Recommendations

### High Priority ✅
1. ✅ **Email template improved** - All alerts now show actionable info
2. ⚠️ **Monitor CT150 disk** - Currently at 76%, approaching 80% threshold
3. ⚠️ **Clean Prometheus data** - 15GB TSDB could be reduced with retention policy

### Medium Priority
1. Add bot-specific action items to email template
2. Add TrueNAS-specific action items to email template
3. Add Windows-specific action items to email template
4. Implement Prometheus retention policy (30 days recommended)

### Low Priority
1. Expand CT150 disk from 32GB to 64GB
2. Configure journal log rotation (SystemMaxUse=1G)
3. Monitor other containers approaching 70% (haproxy, ldc-staging)

---

## Verification

**Test email notifications:**
```bash
# Trigger test alert
ssh prox "pct exec 150 -- amtool alert add test_alert alertname=TestAlert instance=test:9100 severity=warning summary='Test alert' description='This is a test alert to verify email formatting'"

# Check Alertmanager
ssh prox "pct exec 150 -- amtool alert query"

# Check email delivery
# (Check cory@cloudigan.com inbox)
```

**Check Prometheus alerts:**
```bash
# View active alerts
ssh prox "pct exec 150 -- curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, instance: .labels.instance, state: .state}'"
```

---

## Summary

✅ **All 26 alert rules have proper annotations**  
✅ **Email template provides actionable information**  
✅ **7 alerts have custom remediation steps**  
✅ **19 alerts use generic template (still useful)**  
⚠️ **CT150 disk at 76%** - Monitor and clean if needed  
📊 **Prometheus shows exact disk usage per container**

---

**Last Updated:** April 18, 2026  
**Next Review:** Monitor CT150 disk usage, add more custom action items to email template
