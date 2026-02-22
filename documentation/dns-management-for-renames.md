# DNS & Hostname Management for Container Renames

**Created:** 2026-02-22  
**Purpose:** Comprehensive DNS/hostname update strategy for container rename operations  
**Scope:** All systems that reference container hostnames

---

## Systems Requiring DNS/Hostname Updates

### 1. **DC-01 (Windows Domain Controller)** - VMID 108
- **IP:** 10.92.0.10 (primary DNS server)
- **Role:** Active Directory DNS server
- **Network:** VLAN 920 (management)
- **Access:** RDP or PowerShell remoting
- **DNS Zone:** `cloudigan.net` (likely)

**Update Method:**
```powershell
# Option 1: PowerShell DNS cmdlets (recommended for automation)
# Connect via PowerShell remoting or RDP

# Remove old A record
Remove-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "old-hostname" -RRType A -Force

# Add new A record
Add-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "new-hostname" -A -IPv4Address "10.92.3.x"

# Verify
Get-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "new-hostname"
```

**Automation Options:**
1. **PowerShell Remoting** - Requires WinRM enabled on DC-01
2. **SSH to DC-01** - If OpenSSH server installed on Windows
3. **Manual via RDP** - DNS Manager GUI
4. **dnscmd.exe** - Command-line DNS management

**Required Access:**
- Domain Admin credentials
- WinRM/RDP access to DC-01
- DNS management permissions

---

### 2. **AdGuard Home** - CT113 (10.92.3.11)
- **Role:** DNS filtering and local DNS resolution
- **Config Location:** `/opt/AdGuardHome/AdGuardHome.yaml`
- **Web UI:** `http://10.92.3.11:3000`
- **API:** Available for automation

**Update Method:**
```bash
# Option 1: Via Web UI
# Navigate to Filters → DNS rewrites
# Update hostname entries manually

# Option 2: Via API (recommended for automation)
curl -X POST http://10.92.3.11:3000/control/rewrite/add \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "new-hostname.cloudigan.net",
    "answer": "10.92.3.x"
  }'

# Remove old entry
curl -X POST http://10.92.3.11:3000/control/rewrite/delete \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "old-hostname.cloudigan.net",
    "answer": "10.92.3.x"
  }'

# Option 3: Edit config file directly
ssh prox "pct exec 113 -- nano /opt/AdGuardHome/AdGuardHome.yaml"
# Find 'rewrites:' section, update entries
ssh prox "pct exec 113 -- systemctl restart AdGuardHome"
```

**Automation Capability:** High (API available)

---

### 3. **Nginx Proxy Manager (NPM)** - CT121 (10.92.3.3)
- **Role:** Reverse proxy with SSL termination
- **Web UI:** `http://10.92.3.3:81`
- **API:** Available for automation
- **Database:** SQLite at `/data/database.sqlite`

**Update Method:**
```bash
# Option 1: Via Web UI
# Navigate to Hosts → Proxy Hosts
# Edit each proxy host entry
# Update "Forward Hostname/IP" if using hostname (most use IPs - safe)

# Option 2: Via API (recommended)
# Get auth token first
TOKEN=$(curl -X POST http://10.92.3.3:81/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","secret":"password"}' | jq -r '.token')

# List proxy hosts
curl -X GET http://10.92.3.3:81/api/nginx/proxy-hosts \
  -H "Authorization: Bearer $TOKEN"

# Update proxy host (if needed - most use IPs)
curl -X PUT http://10.92.3.3:81/api/nginx/proxy-hosts/{id} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{...updated config...}'

# Option 3: Direct database update (advanced)
ssh prox "pct exec 121 -- sqlite3 /data/database.sqlite \"SELECT * FROM proxy_host WHERE forward_host LIKE '%old-hostname%'\""
```

**Current Status:** Most NPM entries use IP addresses (safe for renames)

**Automation Capability:** High (API available)

---

### 4. **Netbox IPAM** - CT118 (10.92.3.18)
- **Role:** IP address and infrastructure management
- **Web UI:** `http://netbox.cloudigan.net` or `http://10.92.3.18`
- **API:** Full REST API available
- **Database:** PostgreSQL

**Update Method:**
```bash
# Option 1: Via Web UI
# Navigate to Devices → Virtual Machines
# Find container by IP or old name
# Update "Name" field
# Add note: "Renamed from {old-name} on {date}"

# Option 2: Via API (recommended for automation)
# Get API token from Netbox UI: Admin → API Tokens

# Find VM by name
curl -X GET "http://10.92.3.18/api/virtualization/virtual-machines/?name=old-hostname" \
  -H "Authorization: Token YOUR_API_TOKEN" \
  -H "Accept: application/json"

# Update VM name
curl -X PATCH "http://10.92.3.18/api/virtualization/virtual-machines/{id}/" \
  -H "Authorization: Token YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "new-hostname",
    "comments": "Renamed from old-hostname on 2026-02-22"
  }'

# Option 3: Python script using pynetbox
python3 << EOF
import pynetbox
nb = pynetbox.api('http://10.92.3.18', token='YOUR_API_TOKEN')
vm = nb.virtualization.virtual_machines.get(name='old-hostname')
vm.name = 'new-hostname'
vm.comments = 'Renamed from old-hostname on 2026-02-22'
vm.save()
EOF
```

**Automation Capability:** Excellent (Full REST API + Python library)

---

### 5. **Prometheus** - CT150 (10.92.3.2:9090)
- **Role:** Metrics collection and monitoring
- **Config:** `/etc/prometheus/prometheus.yml`
- **Impact:** Uses IP-based targeting (mostly safe)

**Update Method:**
```bash
# Check if any scrape configs use hostname
ssh prox "pct exec 150 -- grep -r 'old-hostname' /etc/prometheus/"

# Update labels if needed (e.g., CT150 self-monitoring)
ssh prox "pct exec 150 -- nano /etc/prometheus/prometheus.yml"
# Change instance label from 'monitor' to 'monitoring-stack'

# Reload Prometheus
ssh prox "pct exec 150 -- systemctl reload prometheus"

# Verify
curl http://10.92.3.2:9090/api/v1/targets | jq
```

**Current Status:** All scrape configs use IPs, only labels need updates

**Automation Capability:** Medium (file-based config, requires reload)

---

### 6. **Grafana** - CT150 (10.92.3.2:3000)
- **Role:** Metrics visualization and dashboards
- **Config:** `/etc/grafana/grafana.ini`
- **Database:** SQLite at `/var/lib/grafana/grafana.db`

**Update Method:**
```bash
# Check for hostname references in dashboards
ssh prox "pct exec 150 -- sqlite3 /var/lib/grafana/grafana.db \"SELECT * FROM dashboard WHERE data LIKE '%old-hostname%'\""

# Most dashboards use Prometheus labels (already IP-based)
# Manual update via UI if needed:
# Navigate to dashboard → Edit → Update queries
```

**Current Status:** Dashboards use Prometheus labels (safe)

**Automation Capability:** Low (dashboard JSON updates complex)

---

### 7. **HAProxy** - CT136 (10.92.3.26) + CT139 (standby)
- **Role:** Load balancer for blue-green deployments
- **Config:** `/etc/haproxy/haproxy.cfg`
- **Impact:** TheoShift blue/green backends

**Update Method:**
```bash
# Check backend configurations
ssh prox "pct exec 136 -- grep -A 5 'backend.*theoshift' /etc/haproxy/haproxy.cfg"

# Update if using hostnames (likely uses IPs)
ssh prox "pct exec 136 -- nano /etc/haproxy/haproxy.cfg"

# Reload HAProxy
ssh prox "pct exec 136 -- systemctl reload haproxy"

# Verify
ssh prox "pct exec 136 -- haproxy -c -f /etc/haproxy/haproxy.cfg"
```

**Required for:** CT132 (green-theoshift), CT134 (blue-theoshift)

**Automation Capability:** Medium (file-based, requires validation)

---

### 8. **SSH Config** - Local Workstation
- **Location:** `~/.ssh/config`
- **Impact:** SSH aliases for direct container access

**Update Method:**
```bash
# Check for existing aliases
grep -E 'npm|sandbox|monitor|netbox|quantshift|theoshift' ~/.ssh/config

# Update manually
nano ~/.ssh/config

# Example:
# Old:
# Host npm
#     HostName 10.92.3.3
#     User root
#
# New:
# Host nginx-proxy
#     HostName 10.92.3.3
#     User root
```

**Automation Capability:** Low (manual edit recommended)

---

### 9. **Documentation** - Multiple Files
- **infrastructure-spec.md** - Container inventory
- **APP-MAP.md** - Application mapping
- **container-naming-standard.md** - Naming standard
- **container-rename-plan.md** - This plan

**Update Method:**
```bash
# Search and replace in documentation
cd /Users/cory/Projects/homelab-nexus
grep -r "old-hostname" documentation/ .cloudy-work/

# Update files
# Commit changes
```

**Automation Capability:** High (grep + sed/awk)

---

### 10. **Windsurf Workflows & MCP Servers**
- **Location:** `.windsurf/workflows/`, `.cloudy-work/`
- **Impact:** Hardcoded IPs and hostnames in workflows

**Update Method:**
```bash
# Search for references
grep -r "old-hostname\|10.92.3.x" .windsurf/ .cloudy-work/

# Update workflow files
# Test workflows after update
```

**Automation Capability:** Medium (requires workflow testing)

---

## Recommended DNS Management Strategy

### Option 1: Manual Updates (Safest for First Time)
1. Update DC-01 DNS via RDP/PowerShell
2. Update AdGuard via Web UI
3. Update Netbox via Web UI
4. Update NPM if needed (most use IPs)
5. Update Prometheus labels if needed
6. Update HAProxy config if needed
7. Update SSH config locally
8. Update documentation

**Pros:** Full visibility, easy rollback  
**Cons:** Time-consuming (30-45 min per container)

---

### Option 2: Semi-Automated (Recommended)
1. **DC-01:** PowerShell script via WinRM
2. **AdGuard:** API calls
3. **Netbox:** API calls (pynetbox)
4. **NPM:** Verify IPs used (skip if true)
5. **Prometheus:** Manual label updates (rare)
6. **HAProxy:** Manual verification (TheoShift only)
7. **SSH config:** Manual update
8. **Documentation:** grep + sed automation

**Pros:** Faster, repeatable, documented  
**Cons:** Requires API tokens, WinRM setup

---

### Option 3: Fully Automated (Future Goal)
Create a Python script that:
1. Reads container rename mapping
2. Updates DC-01 DNS via PowerShell remoting
3. Updates AdGuard via API
4. Updates Netbox via pynetbox
5. Updates NPM via API (if needed)
6. Updates Prometheus config and reloads
7. Updates documentation via sed
8. Generates verification report

**Pros:** Fastest, most consistent  
**Cons:** Complex, requires testing, single point of failure

---

## Immediate Action Plan for Container Renames

### Pre-Rename DNS Checklist

**For Each Container:**

1. **Check DC-01 DNS:**
   ```powershell
   # RDP to DC-01 (10.92.0.10)
   Get-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "old-hostname"
   ```

2. **Check AdGuard:**
   ```bash
   # Check for DNS rewrites
   curl http://10.92.3.11:3000/control/rewrite/list
   ```

3. **Check Netbox:**
   ```bash
   # Via Web UI: http://netbox.cloudigan.net
   # Search for container by IP or name
   ```

4. **Check NPM:**
   ```bash
   # Via Web UI: http://10.92.3.3:81
   # Check if any proxy hosts use hostname (most use IPs)
   ```

5. **Check Prometheus:**
   ```bash
   ssh prox "pct exec 150 -- grep 'old-hostname' /etc/prometheus/prometheus.yml"
   ```

6. **Check HAProxy (TheoShift only):**
   ```bash
   ssh prox "pct exec 136 -- grep 'old-hostname' /etc/haproxy/haproxy.cfg"
   ```

---

### Post-Rename DNS Update Procedure

**For Each Container:**

1. **Update DC-01 DNS:**
   ```powershell
   # Remove old record
   Remove-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "old-hostname" -RRType A -Force
   
   # Add new record
   Add-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "new-hostname" -A -IPv4Address "10.92.3.x"
   
   # Verify
   nslookup new-hostname.cloudigan.net 10.92.0.10
   ```

2. **Update AdGuard (if DNS rewrite exists):**
   ```bash
   # Remove old
   curl -X POST http://10.92.3.11:3000/control/rewrite/delete \
     -H "Content-Type: application/json" \
     -d '{"domain": "old-hostname.cloudigan.net", "answer": "10.92.3.x"}'
   
   # Add new
   curl -X POST http://10.92.3.11:3000/control/rewrite/add \
     -H "Content-Type: application/json" \
     -d '{"domain": "new-hostname.cloudigan.net", "answer": "10.92.3.x"}'
   ```

3. **Update Netbox:**
   ```bash
   # Via Web UI or API
   # Update VM name and add comment
   ```

4. **Update NPM (if needed):**
   ```bash
   # Via Web UI
   # Update proxy host forward hostname (rare - most use IPs)
   ```

5. **Update Prometheus (if needed):**
   ```bash
   # Update labels in prometheus.yml
   ssh prox "pct exec 150 -- systemctl reload prometheus"
   ```

6. **Update HAProxy (TheoShift only):**
   ```bash
   # Update backend server names
   ssh prox "pct exec 136 -- systemctl reload haproxy"
   ```

7. **Update SSH config:**
   ```bash
   nano ~/.ssh/config
   # Update Host alias
   ```

8. **Update Documentation:**
   ```bash
   # Update all .md files with new hostname
   git commit -m "docs: update hostname references for {container}"
   ```

---

## DNS Verification Commands

### Test DNS Resolution
```bash
# Test from Proxmox host
ssh prox "nslookup new-hostname.cloudigan.net 10.92.0.10"

# Test from container
ssh prox "pct exec <CTID> -- nslookup new-hostname.cloudigan.net"

# Test from workstation
nslookup new-hostname.cloudigan.net 10.92.0.10
```

### Test Connectivity
```bash
# Ping by hostname
ping new-hostname.cloudigan.net

# SSH by hostname
ssh root@new-hostname.cloudigan.net

# HTTP by hostname
curl http://new-hostname.cloudigan.net
```

---

## Automation Script Template (Future)

```python
#!/usr/bin/env python3
"""
Container Rename DNS Automation Script
Updates DNS across DC-01, AdGuard, Netbox, NPM
"""

import subprocess
import requests
import pynetbox

def update_dc01_dns(old_name, new_name, ip):
    """Update Windows DNS via PowerShell remoting"""
    ps_script = f"""
    Remove-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "{old_name}" -RRType A -Force
    Add-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "{new_name}" -A -IPv4Address "{ip}"
    """
    # Execute via WinRM or SSH
    pass

def update_adguard_dns(old_name, new_name, ip):
    """Update AdGuard DNS rewrites via API"""
    api_url = "http://10.92.3.11:3000/control/rewrite"
    # Delete old
    requests.post(f"{api_url}/delete", json={"domain": f"{old_name}.cloudigan.net", "answer": ip})
    # Add new
    requests.post(f"{api_url}/add", json={"domain": f"{new_name}.cloudigan.net", "answer": ip})

def update_netbox(old_name, new_name, ctid):
    """Update Netbox VM name via API"""
    nb = pynetbox.api('http://10.92.3.18', token='YOUR_TOKEN')
    vm = nb.virtualization.virtual_machines.get(name=old_name)
    vm.name = new_name
    vm.comments = f"Renamed from {old_name} on 2026-02-22"
    vm.save()

def main():
    renames = [
        {"ctid": 119, "old": "sandbox-01", "new": "bni-toolkit-dev", "ip": "10.92.3.13"},
        # ... more renames
    ]
    
    for rename in renames:
        print(f"Updating DNS for {rename['old']} -> {rename['new']}")
        update_dc01_dns(rename['old'], rename['new'], rename['ip'])
        update_adguard_dns(rename['old'], rename['new'], rename['ip'])
        update_netbox(rename['old'], rename['new'], rename['ctid'])
        print(f"✅ Complete")

if __name__ == "__main__":
    main()
```

---

## Summary

**Systems Requiring Updates:** 10 (DC-01, AdGuard, Netbox, NPM, Prometheus, Grafana, HAProxy, SSH, Docs, Workflows)

**Automation Capability:**
- **High:** AdGuard (API), Netbox (API), Documentation (grep/sed)
- **Medium:** DC-01 (PowerShell), NPM (API), Prometheus (config file)
- **Low:** HAProxy (manual verification), SSH config (manual), Grafana (complex)

**Recommended Approach:**
1. Start with manual updates for first 1-2 containers
2. Build semi-automated scripts for repetitive tasks
3. Create full automation script for future renames

**Critical:** DC-01 and AdGuard are primary DNS servers - these MUST be updated for hostname resolution to work.

---

**Last Updated:** 2026-02-22  
**Status:** Planning - Ready for implementation with Phase 3
