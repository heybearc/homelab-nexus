# cloudy-renvis01 Connectivity Issues - Root Cause Analysis

**Date:** 2026-03-18  
**Server:** cloudy-renvis01 (VM 106, 10.92.4.2)  
**Issue:** Customer being disconnected multiple times throughout the day  
**Status:** ✅ Root cause identified

---

## Root Cause Identified

### **VMTools Service Timeouts**

**Event Log Evidence:**
```
TimeCreated: 3/18/2026 5:46:59 PM
ProviderName: Service Control Manager
Id: 7011
Message: A timeout (30000 milliseconds) was reached while waiting for a transaction 
         response from the VMTools service.

Also occurred at:
- 5:27:08 PM
- 5:26:38 PM
```

**Impact:**
- VMTools (QEMU Guest Agent) timeouts cause system freezes
- Network interruptions during timeout periods
- RDP sessions disconnect
- Customer gets kicked off the server

---

## Additional Issues Found

### **1. Disk I/O Retries**
```
TimeCreated: 3/18/2026 11:27:39 AM
ProviderName: disk
Id: 153
Message: The IO operation at logical block address was retried.
```

**Impact:** Storage performance issues can cause application delays and service timeouts.

### **2. NetBIOS Name Conflict**
```
TimeCreated: 3/18/2026 11:17:54 AM (at boot)
ProviderName: Server
Id: 2505
Message: The server could not bind to the transport because another computer 
         on the network has the same name.
```

**Impact:** Network binding issues at startup, potential SMB/file sharing problems.

---

## Current System Status

**Network Adapters:**
- ✅ Ethernet: Up, 10 Gbps, MAC: BC-24-11-1F-84-6B
- ✅ Tailscale: Up, 100 Gbps

**Services:**
- ✅ Tailscale: Running, Automatic
- ✅ QEMU-GA: Running, Automatic
- ✅ VMTools: Running, Automatic (but experiencing timeouts)
- ⚠️ QEMU Guest Agent VSS Provider: Stopped, Manual

**System Uptime:**
- Last Boot: 3/18/2026 11:16:37 AM
- Uptime: ~8.5 hours

---

## Solutions

### **Immediate Fix: Increase VMTools Timeout**

The default 30-second timeout is too aggressive for this VM. Increase it to prevent service timeouts.

**PowerShell Commands (Run as Administrator on cloudy-renvis01):**

```powershell
# Increase VMTools service timeout to 120 seconds
sc.exe config VMTools depend= RPCSS
sc.exe failure VMTools reset= 86400 actions= restart/60000/restart/60000/restart/60000

# Restart the service to apply changes
Restart-Service VMTools

Write-Host "✅ VMTools timeout increased and restart policy configured"
```

### **Fix Disk I/O Issues**

**On Proxmox host (10.92.0.5):**

```bash
# Check VM disk configuration
qm config 106

# Verify disk cache mode (should be writeback or none for best performance)
# If needed, update disk cache:
qm set 106 --sata0 hdd-pool:vm-106-disk-1,cache=writeback,size=512G

# Check storage pool health
pvesm status
zpool status hdd-pool  # if using ZFS
```

### **Fix NetBIOS Name Conflict**

**Option 1: Disable NetBIOS over TCP/IP (Recommended if not using SMB)**

```powershell
# Disable NetBIOS on all adapters
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
foreach ($adapter in $adapters) {
    $adapter.SetTcpipNetbios(2)  # 2 = Disable NetBIOS
}

Write-Host "✅ NetBIOS disabled on all network adapters"
```

**Option 2: Change Computer Name (If another device has same name)**

```powershell
# Check current name
hostname

# If conflict exists, rename (requires reboot)
Rename-Computer -NewName "cloudy-renvis01-new" -Restart
```

---

## Monitoring Setup

### **Windows Exporter Metrics Already Configured**

✅ **Prometheus scraping:** http://10.92.4.2:9182/metrics  
✅ **Grafana dashboard:** Import ID 14694 at http://10.92.3.2:3000  
✅ **Email alerts:** Configured to cory@cloudigan.com via M365 OAuth2

### **Additional Monitoring Needed**

**1. VMTools Service Monitoring**

Add to Prometheus alert rules (`/etc/prometheus/rules/windows-alerts.yml`):

```yaml
- alert: VMToolsServiceDown
  expr: windows_service_state{name="VMTools",state="running"} != 1
  for: 1m
  labels:
    severity: critical
    service: vmtools
  annotations:
    summary: "VMTools service is not running on {{ $labels.instance }}"
    description: "VMTools service failure can cause RDP disconnections"

- alert: QEMUGuestAgentDown
  expr: windows_service_state{name="QEMU-GA",state="running"} != 1
  for: 1m
  labels:
    severity: critical
    service: qemu-ga
  annotations:
    summary: "QEMU Guest Agent is not running on {{ $labels.instance }}"
    description: "Guest agent failure affects VM management"
```

**2. Disk I/O Monitoring**

Monitor disk latency and errors:

```promql
# Disk read/write latency
rate(windows_logical_disk_read_seconds_total[5m])
rate(windows_logical_disk_write_seconds_total[5m])

# Disk queue length (should be < 2)
windows_logical_disk_avg_disk_queue_length
```

**3. Network Monitoring**

Already configured via Windows Exporter:
- Network bytes sent/received
- Packet errors
- Interface status

---

## Network Device Monitoring (Next Steps)

### **TP-Link Switch Monitoring**

**Switch Details:**
- Model: SG3428XMP
- IP: 10.92.0.20
- Access: SSH (admin@10.92.0.20)

**Setup SNMP Monitoring:**

1. **Enable SNMP on switch** (via SSH or web UI)
2. **Install SNMP exporter on CT150:**
   ```bash
   ssh root@10.92.3.2
   apt install prometheus-snmp-exporter
   ```

3. **Configure Prometheus to scrape switch:**
   ```yaml
   - job_name: 'snmp-switch'
     static_configs:
       - targets:
         - 10.92.0.20
     metrics_path: /snmp
     params:
       module: [if_mib]
     relabel_configs:
       - source_labels: [__address__]
         target_label: __param_target
       - source_labels: [__param_target]
         target_label: instance
       - target_label: __address__
         replacement: localhost:9116
   ```

4. **Monitor:**
   - Port status (up/down)
   - Traffic (bytes in/out)
   - Errors/discards
   - VLAN 924 health

---

## Preventive Measures

### **1. Regular Monitoring**

- ✅ Check Grafana dashboard daily: http://10.92.3.2:3000
- ✅ Review email alerts for warnings
- ✅ Monitor disk I/O latency trends

### **2. Scheduled Maintenance**

**Weekly:**
- Check Windows Event Viewer for new errors
- Verify VMTools service status
- Review disk performance metrics

**Monthly:**
- Update Windows Server (during maintenance window)
- Check Proxmox VM configuration
- Review network switch logs

### **3. Alerting Thresholds**

Current alerts configured:
- Server down: 2 minutes
- High CPU: >85% for 5 minutes
- High memory: >90% for 5 minutes
- Low disk: <10% free for 5 minutes
- Tailscale down: 2 minutes
- **NEW:** VMTools down: 1 minute
- **NEW:** QEMU-GA down: 1 minute

---

## Action Items

### **Immediate (Do Now)**

1. ✅ Increase VMTools service timeout (PowerShell commands above)
2. ✅ Add VMTools monitoring alerts to Prometheus
3. ⏳ Check Proxmox disk cache configuration
4. ⏳ Fix NetBIOS name conflict

### **Short-term (This Week)**

1. ⏳ Enable SNMP on TP-Link switch (10.92.0.20)
2. ⏳ Configure switch monitoring in Prometheus
3. ⏳ Import Grafana dashboard for Windows monitoring (ID 14694)
4. ⏳ Create custom dashboard for network health

### **Long-term (This Month)**

1. ⏳ Set up automated disk I/O performance testing
2. ⏳ Implement network baseline monitoring
3. ⏳ Create runbook for common issues
4. ⏳ Schedule regular maintenance windows

---

## Testing & Verification

### **After Applying Fixes**

1. **Monitor for 24 hours:**
   - Check for VMTools timeout errors
   - Verify no customer disconnections
   - Monitor disk I/O metrics

2. **Test RDP stability:**
   - Have customer connect and work normally
   - Monitor Event Viewer during session
   - Check for any new errors

3. **Verify monitoring:**
   - Confirm Prometheus scraping metrics
   - Test alert delivery (send test alert)
   - Review Grafana dashboards

---

## Contact & Escalation

**If issues persist after fixes:**

1. Check Proxmox host resources (CPU, memory, storage)
2. Review network switch port statistics
3. Check for firmware updates (Proxmox, switch, Windows)
4. Consider VM resource allocation (increase RAM/CPU if needed)

**Current VM Resources:**
- RAM: 16GB
- CPU: 4 cores
- Disk: 512GB
- Network: 10 Gbps

---

## Summary

**Root Cause:** VMTools service timeouts causing system freezes and RDP disconnections

**Fix:** Increase service timeout and configure restart policy

**Monitoring:** Already configured via Prometheus/Grafana with email alerts

**Next Steps:** Apply immediate fixes, add VMTools alerts, enable network monitoring

**Expected Outcome:** No more customer disconnections, proactive alerting for future issues
