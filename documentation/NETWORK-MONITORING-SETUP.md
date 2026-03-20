# Network Device Monitoring Setup

**Date:** 2026-03-18  
**Status:** In Progress

---

## Network Infrastructure

### **Core Switch**
- **Model:** TP-Link SG3428XMP
- **IP:** 10.92.0.2
- **Username:** admin
- **Password:** xmk@xyf7qyq9hac7MGU
- **Management:** Web UI at http://10.92.0.2

### **Gateway/Router**
- **Model:** TP-Link
- **IP:** 10.92.0.1
- **Username:** cloudy_admin
- **Password:** dxn.ruf5MTB8mbk8npc
- **Management:** Web UI at http://10.92.0.1

---

## SNMP Configuration Required

### **Enable SNMP on TP-Link Switch (10.92.0.2)**

**Via Web UI:**

1. **Login to switch:**
   - Go to: http://10.92.0.2
   - Username: `admin`
   - Password: `xmk@xyf7qyq9hac7MGU`

2. **Navigate to SNMP settings:**
   - Go to: **System** → **SNMP** → **SNMP Config**

3. **Enable SNMP v2c:**
   - Enable SNMP: **Yes**
   - SNMP Version: **v1/v2c**
   - Community String (Read): `public` or `homelab_monitor`
   - Community String (Write): Leave disabled for security

4. **Configure SNMP settings:**
   - System Name: `core-switch`
   - System Location: `Homelab Rack`
   - System Contact: `admin@cloudigan.com`

5. **Save configuration**

### **Enable SNMP on Gateway (10.92.0.1) - Optional**

Same steps as above if you want to monitor the gateway.

---

## Prometheus SNMP Exporter Setup

### **Install SNMP Exporter on CT150 (monitoring-stack)**

```bash
ssh root@10.92.3.2

# Install SNMP exporter
apt update
apt install prometheus-snmp-exporter -y

# Verify it's running
systemctl status prometheus-snmp-exporter
```

### **Configure Prometheus to Scrape Switch**

Add to `/etc/prometheus/prometheus.yml`:

```yaml
  - job_name: 'snmp-switch'
    static_configs:
      - targets:
        - 10.92.0.2  # TP-Link switch
    metrics_path: /snmp
    params:
      module: [if_mib]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9116  # SNMP exporter address
```

### **Restart Prometheus**

```bash
systemctl restart prometheus
```

---

## Metrics to Monitor

### **Switch Metrics**
- Port status (up/down)
- Interface traffic (bytes in/out)
- Packet errors/discards
- Port utilization
- VLAN status

### **Important Ports**
- Port connected to cloudy-renvis01 (VM 106)
- Uplink ports
- VLAN 924 ports

---

## Grafana Dashboard

### **Import Network Dashboard**

1. Go to: http://10.92.3.2:3000
2. Login: admin / Cloudy_92!
3. Click **+** → **Import**
4. Enter Dashboard ID: **11169** (SNMP Interface Throughput)
5. Select Prometheus data source
6. Click Import

### **Alternative Dashboards**
- **1124** - SNMP Stats
- **11169** - SNMP Interface Throughput
- **10242** - Network UPS Tools

---

## Alert Rules for Network Monitoring

Add to `/etc/prometheus/rules/network-alerts.yml`:

```yaml
groups:
  - name: network_alerts
    interval: 30s
    rules:
      # Switch Port Down
      - alert: SwitchPortDown
        expr: ifOperStatus{job="snmp-switch"} == 2
        for: 2m
        labels:
          severity: warning
          service: network
        annotations:
          summary: "Switch port {{ $labels.ifDescr }} is down"
          description: "Port {{ $labels.ifDescr }} on {{ $labels.instance }} has been down for 2 minutes"

      # High Interface Errors
      - alert: HighInterfaceErrors
        expr: rate(ifInErrors{job="snmp-switch"}[5m]) > 10
        for: 5m
        labels:
          severity: warning
          service: network
        annotations:
          summary: "High error rate on {{ $labels.ifDescr }}"
          description: "Interface {{ $labels.ifDescr }} has {{ $value }} errors/sec"

      # High Bandwidth Utilization
      - alert: HighBandwidthUtilization
        expr: (rate(ifHCInOctets{job="snmp-switch"}[5m]) * 8 / ifHighSpeed{job="snmp-switch"} * 100) > 80
        for: 10m
        labels:
          severity: warning
          service: network
        annotations:
          summary: "High bandwidth on {{ $labels.ifDescr }}"
          description: "Interface {{ $labels.ifDescr }} is at {{ $value }}% utilization"
```

---

## Testing SNMP

### **Test SNMP from monitoring stack:**

```bash
ssh root@10.92.3.2

# Install snmp tools if not present
apt install snmp snmp-mibs-downloader -y

# Test SNMP connectivity
snmpwalk -v2c -c public 10.92.0.2 system

# Get interface information
snmpwalk -v2c -c public 10.92.0.2 ifDescr

# Get interface status
snmpwalk -v2c -c public 10.92.0.2 ifOperStatus
```

---

## NetBIOS Name Conflict Resolution

### **Issue Found**
At boot time (11:17 AM), Windows Event Log showed:
```
The server could not bind to the transport because another 
computer on the network has the same name.
```

### **Current Configuration**
- **Computer Name:** CLOUDY-RENVIS01
- **Workgroup:** CLOUDIGAN
- **NetBIOS Names Registered:**
  - CLOUDY-RENVIS01<00> (Workstation)
  - CLOUDIGAN<00> (Workgroup)
  - CLOUDY-RENVIS01<20> (Server)

### **Resolution Options**

**Option 1: Disable NetBIOS (Recommended if not using SMB file sharing)**

```powershell
# On cloudy-renvis01
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
foreach ($adapter in $adapters) {
    $adapter.SetTcpipNetbios(2)  # 2 = Disable NetBIOS
}
```

**Option 2: Find Conflicting Device**

```bash
# From any Linux machine on network
nmblookup CLOUDY-RENVIS01

# Or scan for NetBIOS names
nbtscan 10.92.4.0/24
```

**Option 3: Rename if Conflict Persists**

```powershell
# Only if another device legitimately has this name
Rename-Computer -NewName "renvis01" -Restart
```

### **Recommendation**
The error occurred at boot and hasn't repeated. This was likely a transient issue during network initialization. Monitor for recurrence. If it happens again, disable NetBIOS as it's not needed for RDP or Tailscale connectivity.

---

## Summary of Fixes Applied

### ✅ **Completed**

1. **VMTools Service Timeout Fix**
   - Configured auto-restart on failure
   - Added Prometheus alerts for VMTools and QEMU-GA

2. **Disk Cache Optimization**
   - Changed from `none` to `writeback` cache mode
   - Should improve disk I/O performance and reduce retries

3. **Monitoring Alerts Added**
   - VMTools service down (1min alert)
   - QEMU-GA service down (1min alert)
   - Email alerts to cory@cloudigan.com

### ⏳ **Pending (Manual Steps Required)**

1. **Enable SNMP on Switch**
   - Login to http://10.92.0.2
   - Enable SNMP v2c with community string
   - Configure system information

2. **Install SNMP Exporter**
   - Run commands on CT150 (monitoring-stack)
   - Configure Prometheus scraping
   - Import Grafana dashboard

3. **Update Netbox**
   - Add cloudy-renvis01 VM details
   - Document network configuration
   - Add switch and gateway information

---

## Next Steps

1. **Enable SNMP on switch** (5 minutes)
   - Follow web UI instructions above

2. **Configure SNMP monitoring** (10 minutes)
   - Install exporter on CT150
   - Update Prometheus config
   - Restart Prometheus

3. **Import Grafana dashboards** (5 minutes)
   - Windows monitoring (ID 14694)
   - Network monitoring (ID 11169)

4. **Monitor for 24 hours**
   - Verify no more customer disconnections
   - Check for VMTools timeout errors
   - Review disk I/O metrics

---

## Expected Outcomes

✅ **No more customer disconnections** - VMTools auto-restart prevents freezes  
✅ **Better disk performance** - Writeback cache reduces I/O latency  
✅ **Proactive network monitoring** - Alerts before network issues affect users  
✅ **Full visibility** - Grafana dashboards for server and network health

---

## Contact Information

**For Issues:**
- Check Grafana: http://10.92.3.2:3000
- Check Prometheus: http://10.92.3.2:9090
- Email alerts: cory@cloudigan.com

**Network Devices:**
- Switch: http://10.92.0.2 (admin / xmk@xyf7qyq9hac7MGU)
- Gateway: http://10.92.0.1 (cloudy_admin / dxn.ruf5MTB8mbk8npc)
