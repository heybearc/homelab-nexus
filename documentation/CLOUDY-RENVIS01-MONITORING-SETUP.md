# cloudy-renvis01 Windows Server Monitoring Setup

**Date:** 2026-03-18  
**Status:** ✅ Complete  
**Alert Email:** cory@cloudigan.com

---

## Server Details

**VM Information:**
- **Name:** cloudy-renvis01
- **VM ID:** 106
- **OS:** Windows Server 2022
- **IP Address:** 10.92.4.2 (VLAN 924)
- **Tailscale IP:** 100.83.60.29
- **Resources:** 16GB RAM, 4 cores, 512GB disk

**Monitoring Stack:**
- **Prometheus:** 10.92.3.2:9090 (CT150)
- **Grafana:** 10.92.3.2:3000 (CT150)
- **Alertmanager:** 10.92.3.2:9093 (CT150)

---

## What's Monitored

### VM-Level Metrics
- ✅ **Server Up/Down** - Alert after 2 minutes down
- ✅ **CPU Usage** - Alert if >85% for 5 minutes
- ✅ **Memory Usage** - Alert if >90% for 5 minutes
- ✅ **Disk Space** - Alert if <10% free for 5 minutes

### Service Monitoring
- ✅ **Tailscale Service** - Alert if down for 2 minutes
- ✅ **Windows Update Service** - Info alert if not running

### Available Metrics (Not Alerted)
- Network I/O (bytes sent/received)
- Disk I/O (read/write operations)
- TCP connections
- Process count
- System uptime
- All Windows services status

---

## Alert Configuration

**Alert Rules File:** `/etc/prometheus/rules/windows-alerts.yml`

**Configured Alerts:**

1. **WindowsServerDown** (Critical)
   - Triggers: Server unreachable for 2 minutes
   - Email: Immediate

2. **WindowsHighCPU** (Warning)
   - Triggers: CPU >85% for 5 minutes
   - Email: After 5 minutes

3. **WindowsHighMemory** (Warning)
   - Triggers: Memory >90% for 5 minutes
   - Email: After 5 minutes

4. **WindowsLowDiskSpace** (Warning)
   - Triggers: Disk <10% free for 5 minutes
   - Email: After 5 minutes

5. **TailscaleServiceDown** (Critical)
   - Triggers: Tailscale service not running for 2 minutes
   - Email: Immediate

**Email Configuration:**
- **From:** noreply@cloudigan.com (via M365 SMTP)
- **To:** cory@cloudigan.com
- **Repeat Interval:** 12 hours (won't spam)
- **Group Interval:** 10 seconds (batches alerts)

---

## Access URLs

**Prometheus:**
- Internal: http://10.92.3.2:9090
- Public: http://prometheus.cloudigan.net (if NPM configured)
- Targets: http://10.92.3.2:9090/targets
- Alerts: http://10.92.3.2:9090/alerts

**Grafana:**
- Internal: http://10.92.3.2:3000
- Public: http://grafana.cloudigan.net (if NPM configured)
- Default Login: admin/admin (change on first login)

**Alertmanager:**
- Internal: http://10.92.3.2:9093
- Public: http://alertmanager.cloudigan.net (if NPM configured)

---

## Grafana Dashboard Setup

### Option 1: Import Pre-built Dashboard (Recommended)

1. Go to Grafana: http://10.92.3.2:3000
2. Login (default: admin/admin)
3. Click **+** → **Import**
4. Enter Dashboard ID: **14694** (Windows Node Exporter Full)
5. Select **Prometheus** as data source
6. Click **Import**

### Option 2: Use Community Dashboards

Popular Windows dashboards:
- **14694** - Windows Node Exporter Full (Recommended)
- **10467** - Windows Node
- **12566** - Windows Exporter Dashboard

### Custom Queries for cloudy-renvis01

```promql
# CPU Usage
100 - (avg(rate(windows_cpu_time_total{instance="cloudy-renvis01",mode="idle"}[5m])) * 100)

# Memory Usage %
100 * (1 - (windows_os_physical_memory_free_bytes{instance="cloudy-renvis01"} / windows_cs_physical_memory_bytes{instance="cloudy-renvis01"}))

# Disk Free %
100 * (windows_logical_disk_free_bytes{instance="cloudy-renvis01"} / windows_logical_disk_size_bytes{instance="cloudy-renvis01"})

# Tailscale Service Status
windows_service_state{instance="cloudy-renvis01",name="Tailscale",state="running"}

# Network Bytes Received
rate(windows_net_bytes_received_total{instance="cloudy-renvis01"}[5m])

# Network Bytes Sent
rate(windows_net_bytes_sent_total{instance="cloudy-renvis01"}[5m])
```

---

## Configuration Files

### Prometheus Configuration
**File:** `/etc/prometheus/prometheus.yml`

```yaml
  - job_name: 'windows-servers'
    static_configs:
      - targets: ['10.92.4.2:9182']
        labels:
          instance: 'cloudy-renvis01'
          environment: 'production'
          os: 'windows'
          vm_id: '106'
```

### Alert Rules
**File:** `/etc/prometheus/rules/windows-alerts.yml`

Contains 5 alert rules for Windows server monitoring (see Alert Configuration section above).

### Alertmanager Configuration
**File:** `/etc/alertmanager/alertmanager.yml`

- SMTP: smtp.office365.com:587
- From: noreply@cloudigan.com
- To: cory@cloudigan.com
- TLS: Enabled

---

## Verification

**Check Prometheus Target:**
```bash
ssh root@10.92.3.2
curl http://localhost:9090/api/v1/targets | grep cloudy-renvis01
```

**Check Windows Exporter Metrics:**
```bash
curl http://10.92.4.2:9182/metrics | grep windows_os
```

**Check Active Alerts:**
```bash
ssh root@10.92.3.2
curl http://localhost:9093/api/v2/alerts
```

**Test Email Alert:**
```bash
ssh root@10.92.3.2
amtool alert add test_alert instance=cloudy-renvis01 severity=warning --alertmanager.url=http://localhost:9093
```

---

## Maintenance

### Add More Services to Monitor

Edit alert rules to monitor additional Windows services:

```bash
ssh root@10.92.3.2
nano /etc/prometheus/rules/windows-alerts.yml
```

Add rule:
```yaml
- alert: ServiceNameDown
  expr: windows_service_state{name="ServiceName",state="running"} != 1
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Service ServiceName is down on {{ $labels.instance }}"
```

Reload Prometheus:
```bash
systemctl restart prometheus
```

### Adjust Alert Thresholds

Edit `/etc/prometheus/rules/windows-alerts.yml` and change values:
- CPU: Change `> 85` to desired percentage
- Memory: Change `> 90` to desired percentage
- Disk: Change `< 10` to desired percentage
- Timing: Change `for: 5m` to desired duration

### Change Email Settings

Edit `/etc/alertmanager/alertmanager.yml`:
```bash
ssh root@10.92.3.2
nano /etc/alertmanager/alertmanager.yml
systemctl restart alertmanager
```

---

## Troubleshooting

### No Metrics in Prometheus

1. Check Windows Exporter service:
   ```powershell
   # On cloudy-renvis01
   Get-Service windows_exporter
   ```

2. Check firewall:
   ```powershell
   Get-NetFirewallRule -DisplayName "Prometheus Windows Exporter"
   ```

3. Test from monitoring stack:
   ```bash
   ssh root@10.92.3.2
   curl http://10.92.4.2:9182/metrics
   ```

### Alerts Not Firing

1. Check Prometheus rules:
   ```bash
   ssh root@10.92.3.2
   promtool check rules /etc/prometheus/rules/windows-alerts.yml
   ```

2. Check Prometheus alerts page:
   - http://10.92.3.2:9090/alerts

3. Check Alertmanager:
   ```bash
   journalctl -u alertmanager -f
   ```

### Email Not Sending

1. Check Alertmanager config:
   ```bash
   ssh root@10.92.3.2
   amtool check-config /etc/alertmanager/alertmanager.yml
   ```

2. Check Alertmanager logs:
   ```bash
   journalctl -u alertmanager --since '10 minutes ago'
   ```

3. Test SMTP manually:
   ```bash
   curl -v --ssl smtp://smtp.office365.com:587
   ```

---

## Next Steps

### Recommended Improvements

1. **Import Grafana Dashboard**
   - Use dashboard ID 14694 for comprehensive Windows monitoring
   - Customize panels for your specific needs

2. **Add More Services**
   - Identify critical Windows services
   - Add alert rules for each service

3. **Configure NPM Proxy**
   - Add grafana.cloudigan.net → 10.92.3.2:3000
   - Add prometheus.cloudigan.net → 10.92.3.2:9090
   - Add alertmanager.cloudigan.net → 10.92.3.2:9093

4. **Set Up Slack/Teams Alerts** (Optional)
   - Configure webhook in Alertmanager
   - Get instant notifications on mobile

5. **Create Custom Dashboards**
   - Build dashboards specific to your workload
   - Add business-specific metrics

---

## Summary

✅ **Monitoring Active:**
- cloudy-renvis01 is being scraped every 15 seconds
- 5 alert rules configured and active
- Email alerts configured to cory@cloudigan.com
- Test alert sent successfully

✅ **What You Get:**
- Immediate alerts for critical issues (server down, services down)
- Warning alerts for resource issues (CPU, memory, disk)
- Historical metrics for troubleshooting
- Ready for Grafana dashboards

✅ **Files Created:**
- `/etc/prometheus/prometheus.yml` - Updated with Windows target
- `/etc/prometheus/rules/windows-alerts.yml` - Alert rules
- `/etc/alertmanager/alertmanager.yml` - Email configuration

**Monitoring is now live and operational!** 🎉

Check your email (cory@cloudigan.com) for the test alert that was sent.
