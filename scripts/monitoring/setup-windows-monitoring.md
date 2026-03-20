# Windows Server Monitoring Setup for cloudy-renvis01

**Date:** 2026-03-18  
**Target:** cloudy-renvis01 (VM 106)  
**IP:** 10.92.4.2  
**OS:** Windows Server 2022  
**Monitoring Stack:** Prometheus (10.92.3.2:9090) + Grafana (10.92.3.2:3000)

---

## Overview

This guide sets up comprehensive monitoring for cloudy-renvis01 including:
- VM up/down status
- Windows services (including Tailscale)
- CPU, Memory, Disk usage
- Network connectivity
- Email alerts to cory@cloudigan.com

---

## Step 1: Install Windows Exporter on cloudy-renvis01

**On cloudy-renvis01 (RDP or PowerShell):**

### Download and Install Windows Exporter

```powershell
# Download latest Windows Exporter
$version = "0.25.1"
$url = "https://github.com/prometheus-community/windows_exporter/releases/download/v$version/windows_exporter-$version-amd64.msi"
$output = "$env:TEMP\windows_exporter.msi"

Invoke-WebRequest -Uri $url -OutFile $output

# Install with specific collectors enabled
msiexec /i $output ENABLED_COLLECTORS="cpu,cs,logical_disk,net,os,service,system,tcp,memory" /qn

# Verify installation
Get-Service windows_exporter

# Check if it's running
Get-Service windows_exporter | Select-Object Status, StartType

# Test metrics endpoint
Invoke-WebRequest -Uri "http://localhost:9182/metrics" -UseBasicParsing | Select-Object -First 20
```

### Configure Firewall Rule

```powershell
# Allow Prometheus to scrape metrics from monitoring stack
New-NetFirewallRule -DisplayName "Prometheus Windows Exporter" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 9182 `
    -Action Allow `
    -RemoteAddress 10.92.3.2 `
    -Profile Any
```

### Verify from Monitoring Stack

```bash
# SSH to monitoring stack
ssh root@10.92.3.2

# Test connectivity
curl http://10.92.4.2:9182/metrics | head -20
```

---

## Step 2: Configure Prometheus to Scrape cloudy-renvis01

**On CT150 (monitoring-stack):**

```bash
# SSH to monitoring stack
ssh root@10.92.3.2

# Backup current config
cp /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.backup

# Add Windows target
cat >> /etc/prometheus/prometheus.yml << 'EOF'

  - job_name: 'windows-servers'
    static_configs:
      - targets: ['10.92.4.2:9182']
        labels:
          instance: 'cloudy-renvis01'
          environment: 'production'
          os: 'windows'
          vm_id: '106'
EOF

# Validate config
promtool check config /etc/prometheus/prometheus.yml

# Reload Prometheus
systemctl reload prometheus

# Verify target is up
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.instance=="cloudy-renvis01")'
```

---

## Step 3: Configure Alert Rules

**Create alert rules file:**

```bash
# On CT150
cat > /etc/prometheus/rules/windows-alerts.yml << 'EOF'
groups:
  - name: windows_server_alerts
    interval: 30s
    rules:
      # VM Down Alert
      - alert: WindowsServerDown
        expr: up{job="windows-servers"} == 0
        for: 2m
        labels:
          severity: critical
          service: infrastructure
        annotations:
          summary: "Windows Server {{ $labels.instance }} is down"
          description: "{{ $labels.instance }} has been unreachable for more than 2 minutes."

      # High CPU Usage
      - alert: WindowsHighCPU
        expr: 100 - (avg by (instance) (rate(windows_cpu_time_total{mode="idle"}[5m])) * 100) > 85
        for: 5m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is {{ $value | humanize }}% on {{ $labels.instance }}"

      # High Memory Usage
      - alert: WindowsHighMemory
        expr: 100 * (1 - (windows_os_physical_memory_free_bytes / windows_cs_physical_memory_bytes)) > 90
        for: 5m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ $value | humanize }}% on {{ $labels.instance }}"

      # Low Disk Space
      - alert: WindowsLowDiskSpace
        expr: 100 * (windows_logical_disk_free_bytes / windows_logical_disk_size_bytes) < 10
        for: 5m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk {{ $labels.volume }} has only {{ $value | humanize }}% free space on {{ $labels.instance }}"

      # Service Down (Tailscale)
      - alert: TailscaleServiceDown
        expr: windows_service_state{name="Tailscale",state="running"} != 1
        for: 2m
        labels:
          severity: critical
          service: tailscale
        annotations:
          summary: "Tailscale service is not running on {{ $labels.instance }}"
          description: "Tailscale service has been down for more than 2 minutes on {{ $labels.instance }}"

      # Windows Update Service
      - alert: WindowsUpdateServiceDown
        expr: windows_service_state{name="wuauserv",state="running"} != 1
        for: 5m
        labels:
          severity: info
          service: windows-update
        annotations:
          summary: "Windows Update service is not running on {{ $labels.instance }}"
          description: "Windows Update service state is {{ $labels.state }} on {{ $labels.instance }}"
EOF

# Update Prometheus config to include rules
sed -i '/rule_files:/a\  - "/etc/prometheus/rules/windows-alerts.yml"' /etc/prometheus/prometheus.yml

# Validate rules
promtool check rules /etc/prometheus/rules/windows-alerts.yml

# Reload Prometheus
systemctl reload prometheus
```

---

## Step 4: Configure Alertmanager for Email

**Update Alertmanager configuration:**

```bash
# On CT150
# Check if email config exists
grep -A 10 "email_configs" /etc/alertmanager/alertmanager.yml

# If not configured, add email settings
cat > /etc/alertmanager/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.office365.com:587'
  smtp_from: 'noreply@cloudigan.com'
  smtp_auth_username: 'noreply@cloudigan.com'
  smtp_auth_password: 'YOUR_APP_PASSWORD_HERE'  # Use M365 app password
  smtp_require_tls: true

route:
  group_by: ['alertname', 'instance']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'email-cory'
  routes:
    - match:
        severity: critical
      receiver: 'email-cory'
      continue: true

receivers:
  - name: 'email-cory'
    email_configs:
      - to: 'cory@cloudigan.com'
        headers:
          Subject: '🚨 {{ .GroupLabels.alertname }} - {{ .GroupLabels.instance }}'
        html: |
          <h2>Alert: {{ .GroupLabels.alertname }}</h2>
          <p><strong>Instance:</strong> {{ .GroupLabels.instance }}</p>
          <p><strong>Severity:</strong> {{ .CommonLabels.severity }}</p>
          <p><strong>Summary:</strong> {{ .CommonAnnotations.summary }}</p>
          <p><strong>Description:</strong> {{ .CommonAnnotations.description }}</p>
          <p><strong>Time:</strong> {{ .StartsAt }}</p>

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF

# Validate config
amtool check-config /etc/alertmanager/alertmanager.yml

# Reload Alertmanager
systemctl reload alertmanager
```

---

## Step 5: Import Grafana Dashboard

**Option 1: Use Pre-built Dashboard**

1. Go to Grafana: http://grafana.cloudigan.net (or http://10.92.3.2:3000)
2. Login (default: admin/admin)
3. Click **+** → **Import**
4. Enter Dashboard ID: **14694** (Windows Node Exporter Full)
5. Select Prometheus data source
6. Click **Import**

**Option 2: Create Custom Dashboard via API**

```bash
# On CT150 or your local machine
curl -X POST http://10.92.3.2:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_GRAFANA_API_KEY" \
  -d @- << 'EOF'
{
  "dashboard": {
    "title": "cloudy-renvis01 - Windows Server Monitoring",
    "tags": ["windows", "infrastructure"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Server Status",
        "type": "stat",
        "targets": [{"expr": "up{instance=\"cloudy-renvis01\"}"}]
      },
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [{"expr": "100 - (avg(rate(windows_cpu_time_total{instance=\"cloudy-renvis01\",mode=\"idle\"}[5m])) * 100)"}]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "targets": [{"expr": "100 * (1 - (windows_os_physical_memory_free_bytes{instance=\"cloudy-renvis01\"} / windows_cs_physical_memory_bytes{instance=\"cloudy-renvis01\"}))"}]
      },
      {
        "title": "Disk Usage",
        "type": "graph",
        "targets": [{"expr": "100 * (windows_logical_disk_free_bytes{instance=\"cloudy-renvis01\"} / windows_logical_disk_size_bytes{instance=\"cloudy-renvis01\"})"}]
      },
      {
        "title": "Tailscale Service Status",
        "type": "stat",
        "targets": [{"expr": "windows_service_state{instance=\"cloudy-renvis01\",name=\"Tailscale\",state=\"running\"}"}]
      }
    ]
  },
  "overwrite": true
}
EOF
```

---

## Step 6: Test Alerting

**Test email alerts:**

```bash
# On CT150
# Send test alert
amtool alert add test_alert instance=cloudy-renvis01 severity=warning

# Check alert status
amtool alert query

# Check Alertmanager logs
journalctl -u alertmanager -f
```

**Verify in Grafana:**
1. Go to Alerting → Alert rules
2. Check that windows_server_alerts are loaded
3. View current alert status

---

## Monitoring Checklist

- [ ] Windows Exporter installed on cloudy-renvis01
- [ ] Firewall rule created (port 9182)
- [ ] Prometheus scraping cloudy-renvis01 (check /targets)
- [ ] Alert rules loaded in Prometheus
- [ ] Alertmanager configured with email
- [ ] Grafana dashboard imported
- [ ] Test alert sent to cory@cloudigan.com
- [ ] Verify all services showing in Grafana

---

## What You'll Monitor

**VM Level:**
- ✅ VM up/down status (2min alert)
- ✅ CPU usage (>85% for 5min)
- ✅ Memory usage (>90% for 5min)
- ✅ Disk space (<10% free)

**Services:**
- ✅ Tailscale service status
- ✅ Windows Update service
- ✅ Any other Windows services you specify

**Metrics Available:**
- Network I/O
- Disk I/O
- Process count
- TCP connections
- System uptime

---

## Next Steps

**You need to:**

1. **RDP to cloudy-renvis01** (10.92.4.2 or via Tailscale 100.83.60.29)
2. **Run the PowerShell commands** from Step 1 to install Windows Exporter
3. **Provide M365 app password** for email alerts (or I can use the existing noreply@cloudigan.com credentials)

**I will:**

1. Configure Prometheus to scrape the metrics
2. Set up alert rules
3. Configure Alertmanager for email
4. Import Grafana dashboard
5. Test the complete monitoring pipeline

**Ready to proceed? Let me know when you've installed Windows Exporter on the server.**
