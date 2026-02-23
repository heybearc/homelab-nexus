# Phase 3: Container Rename Execution Guide

**Created:** 2026-02-23  
**Status:** Ready to Execute  
**Scope:** Batch 1 - 3 Low-Risk Containers

---

## Overview

Phase 3 implements the container renames planned in Phase 2. We'll start with **Batch 1** (3 low-risk, non-production containers) to validate the process before moving to infrastructure and production containers.

---

## Batch 1: Low-Risk, Non-Production Containers

### Containers in This Batch

| CTID | Current Name | New Name | IP | Risk | Est. Time |
|------|--------------|----------|-----|------|-----------|
| 119 | sandbox-01 | bni-toolkit-dev | 10.92.3.13 | Low | 30-45 min |
| 101 | quantshift-standby | quantshift-bot-standby | 10.92.3.28 | Low | 30-45 min |
| 100 | quantshift-primary | quantshift-bot-primary | 10.92.3.27 | Low | 30-45 min |

**Total Estimated Time:** 1.5 - 2.5 hours (including verification)

---

## Pre-Flight Checks (Do Once Before Starting)

### 1. Verify Access to All Systems

```bash
# Test Proxmox access
ssh prox "pct list | head -5"

# Test Netbox access
curl -s http://10.92.3.18 | grep -i netbox

# Test AdGuard access (if needed)
curl -s http://10.92.3.11:3000 | grep -i adguard

# Test Prometheus access
curl -s http://10.92.3.2:9090/-/healthy
```

### 2. Check DC-01 DNS Access

**Option A: RDP to DC-01**
- Open Remote Desktop
- Connect to 10.92.0.10
- Login with domain admin credentials
- Open DNS Manager (dnsmgmt.msc)

**Option B: PowerShell Remoting (if configured)**
```powershell
# Test WinRM connection
Test-WSMan -ComputerName 10.92.0.10

# Test DNS cmdlets
Invoke-Command -ComputerName 10.92.0.10 -ScriptBlock {
    Get-DnsServerResourceRecord -ZoneName "cloudigan.net" | Select-Object -First 5
}
```

### 3. Backup Current State

```bash
# Backup container configs (run for each CTID)
ssh prox "vzdump 119 --mode snapshot --storage local"
ssh prox "vzdump 101 --mode snapshot --storage local"
ssh prox "vzdump 100 --mode snapshot --storage local"

# Export Netbox data (via Web UI)
# Navigate to http://netbox.cloudigan.net
# Admin → Jobs → Export → Virtual Machines

# Screenshot Prometheus targets
# Navigate to http://10.92.3.2:9090/targets
# Take screenshot
```

### 4. Check for Existing DNS Records

```bash
# Check current DNS entries (from DC-01)
# Via DNS Manager or PowerShell:
Get-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "sandbox-01"
Get-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "quantshift-primary"
Get-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "quantshift-standby"
```

### 5. Check SSH Config for Aliases

```bash
# Check for existing SSH aliases
grep -E 'sandbox|quantshift' ~/.ssh/config
```

---

## Container 1: CT119 (sandbox-01 → bni-toolkit-dev)

### Container Details
- **CTID:** 119
- **Current Name:** sandbox-01
- **New Name:** bni-toolkit-dev
- **IP:** 10.92.3.13
- **Purpose:** BNI Chapter Toolkit development environment
- **Risk:** Low (dev container, non-production)

### Step-by-Step Execution

#### Step 1: Pre-Rename Verification
```bash
# Check current hostname
ssh prox "pct exec 119 -- hostname"
# Expected output: sandbox-01

# Verify container is running
ssh prox "pct status 119"
# Expected output: status: running

# Check if any services are running
ssh prox "pct exec 119 -- systemctl list-units --type=service --state=running"
```

#### Step 2: Stop Container
```bash
ssh prox "pct stop 119"

# Verify stopped
ssh prox "pct status 119"
# Expected output: status: stopped
```

#### Step 3: Rename in Proxmox
```bash
ssh prox "pct set 119 --hostname bni-toolkit-dev"

# Verify config updated
ssh prox "grep hostname /etc/pve/lxc/119.conf"
# Expected output: hostname: bni-toolkit-dev
```

#### Step 4: Start Container
```bash
ssh prox "pct start 119"

# Wait for container to boot (10-15 seconds)
sleep 15

# Verify running
ssh prox "pct status 119"
# Expected output: status: running
```

#### Step 5: Verify Hostname Inside Container
```bash
ssh prox "pct exec 119 -- hostname"
# Expected output: bni-toolkit-dev

# Verify hostname file
ssh prox "pct exec 119 -- cat /etc/hostname"
# Expected output: bni-toolkit-dev
```

#### Step 6: Update DNS Systems

**6a. Update DC-01 DNS**

**Via RDP/DNS Manager:**
1. Open DNS Manager on DC-01
2. Expand Forward Lookup Zones → cloudigan.net
3. Find "sandbox-01" A record
4. Right-click → Delete
5. Right-click cloudigan.net → New Host (A or AAAA)
6. Name: bni-toolkit-dev
7. IP: 10.92.3.13
8. Click "Add Host"

**Via PowerShell (if WinRM configured):**
```powershell
# Remove old record
Invoke-Command -ComputerName 10.92.0.10 -ScriptBlock {
    Remove-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "sandbox-01" -RRType A -Force
}

# Add new record
Invoke-Command -ComputerName 10.92.0.10 -ScriptBlock {
    Add-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "bni-toolkit-dev" -A -IPv4Address "10.92.3.13"
}

# Verify
Invoke-Command -ComputerName 10.92.0.10 -ScriptBlock {
    Get-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "bni-toolkit-dev"
}
```

**6b. Update AdGuard DNS (if DNS rewrite exists)**
```bash
# Check for existing rewrites
curl -s http://10.92.3.11:3000/control/rewrite/list | grep sandbox

# If exists, remove old and add new (requires AdGuard credentials)
# Most likely NOT needed for dev containers
```

**6c. Update Netbox IPAM**
1. Navigate to http://netbox.cloudigan.net
2. Search for "sandbox-01" or "10.92.3.13"
3. Click on the VM/Device
4. Click "Edit"
5. Update Name: bni-toolkit-dev
6. Add Comment: "Renamed from sandbox-01 on 2026-02-23"
7. Click "Save"

#### Step 7: Update Documentation
```bash
# Update infrastructure-spec.md
cd /Users/cory/Projects/homelab-nexus
grep -n "sandbox-01" documentation/infrastructure-spec.md

# Update the file (will do via edit tool)
# Change all instances of sandbox-01 to bni-toolkit-dev
```

#### Step 8: Update SSH Config (if exists)
```bash
# Check if alias exists
grep "sandbox" ~/.ssh/config

# If exists, update manually
nano ~/.ssh/config
# Change Host sandbox-01 to Host bni-toolkit-dev
```

#### Step 9: Verify Service Functionality
```bash
# Test DNS resolution
nslookup bni-toolkit-dev.cloudigan.net 10.92.0.10
# Expected: 10.92.3.13

# Test connectivity by hostname
ping -c 3 bni-toolkit-dev.cloudigan.net

# Test SSH by hostname
ssh prox "pct exec 119 -- hostname"
# Expected: bni-toolkit-dev

# Test services (if any running)
ssh prox "pct exec 119 -- systemctl status"
```

#### Step 10: Mark Complete
```bash
# Update progress tracker in container-rename-plan.md
# Mark CT119 as complete with checkmark
```

---

## Container 2: CT101 (quantshift-standby → quantshift-bot-standby)

### Container Details
- **CTID:** 101
- **Current Name:** quantshift-standby
- **New Name:** quantshift-bot-standby
- **IP:** 10.92.3.28
- **Purpose:** QuantShift standby bot (not actively running)
- **Risk:** Low (standby container, not in use)

### Step-by-Step Execution

#### Step 1: Pre-Rename Verification
```bash
# Check current hostname
ssh prox "pct exec 101 -- hostname"
# Expected output: quantshift-standby

# Verify container is running
ssh prox "pct status 101"

# Check if bot is running (should be stopped on standby)
ssh prox "pct exec 101 -- systemctl status quantshift-*"
```

#### Step 2: Stop Container
```bash
ssh prox "pct stop 101"

# Verify stopped
ssh prox "pct status 101"
```

#### Step 3: Rename in Proxmox
```bash
ssh prox "pct set 101 --hostname quantshift-bot-standby"

# Verify config updated
ssh prox "grep hostname /etc/pve/lxc/101.conf"
# Expected output: hostname: quantshift-bot-standby
```

#### Step 4: Start Container
```bash
ssh prox "pct start 101"

# Wait for container to boot
sleep 15

# Verify running
ssh prox "pct status 101"
```

#### Step 5: Verify Hostname Inside Container
```bash
ssh prox "pct exec 101 -- hostname"
# Expected output: quantshift-bot-standby

ssh prox "pct exec 101 -- cat /etc/hostname"
# Expected output: quantshift-bot-standby
```

#### Step 6: Update DNS Systems

**6a. Update DC-01 DNS**

**Via PowerShell:**
```powershell
# Remove old record
Invoke-Command -ComputerName 10.92.0.10 -ScriptBlock {
    Remove-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "quantshift-standby" -RRType A -Force
}

# Add new record
Invoke-Command -ComputerName 10.92.0.10 -ScriptBlock {
    Add-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "quantshift-bot-standby" -A -IPv4Address "10.92.3.28"
}

# Verify
nslookup quantshift-bot-standby.cloudigan.net 10.92.0.10
```

**6b. Update Netbox IPAM**
1. Navigate to http://netbox.cloudigan.net
2. Search for "quantshift-standby" or "10.92.3.28"
3. Update Name: quantshift-bot-standby
4. Add Comment: "Renamed from quantshift-standby on 2026-02-23"
5. Save

#### Step 7: Update Documentation
```bash
# Update infrastructure-spec.md and APP-MAP.md
grep -rn "quantshift-standby" documentation/ .cloudy-work/_cloudy-ops/context/
```

#### Step 8: Verify Service Functionality
```bash
# Test DNS resolution
nslookup quantshift-bot-standby.cloudigan.net 10.92.0.10

# Test connectivity
ping -c 3 quantshift-bot-standby.cloudigan.net

# Verify Prometheus label (should be qs-standby, unchanged)
curl -s http://10.92.3.2:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.container=="ct101")'
```

#### Step 9: Mark Complete
```bash
# Update progress tracker
```

---

## Container 3: CT100 (quantshift-primary → quantshift-bot-primary)

### Container Details
- **CTID:** 100
- **Current Name:** quantshift-primary
- **New Name:** quantshift-bot-primary
- **IP:** 10.92.3.27
- **Purpose:** QuantShift primary bot (actively running)
- **Risk:** Low (bot container, minimal dependencies)
- **⚠️ Note:** This is an active bot - verify bot status before/after

### Step-by-Step Execution

#### Step 1: Pre-Rename Verification
```bash
# Check current hostname
ssh prox "pct exec 100 -- hostname"
# Expected output: quantshift-primary

# Check bot status (important - bot may be running)
ssh prox "pct exec 100 -- systemctl status quantshift-equity"
ssh prox "pct exec 100 -- systemctl status quantshift-crypto"

# Check if bot is actively trading
ssh prox "pct exec 100 -- journalctl -u quantshift-equity -n 20"
```

#### Step 2: Stop Container
```bash
# Note: This will stop the trading bot temporarily (~2 min downtime)
ssh prox "pct stop 100"

# Verify stopped
ssh prox "pct status 100"
```

#### Step 3: Rename in Proxmox
```bash
ssh prox "pct set 100 --hostname quantshift-bot-primary"

# Verify config updated
ssh prox "grep hostname /etc/pve/lxc/100.conf"
```

#### Step 4: Start Container
```bash
ssh prox "pct start 100"

# Wait for container to boot
sleep 15

# Verify running
ssh prox "pct status 100"
```

#### Step 5: Verify Hostname Inside Container
```bash
ssh prox "pct exec 100 -- hostname"
# Expected output: quantshift-bot-primary

ssh prox "pct exec 100 -- cat /etc/hostname"
```

#### Step 6: Update DNS Systems

**6a. Update DC-01 DNS**
```powershell
# Remove old record
Invoke-Command -ComputerName 10.92.0.10 -ScriptBlock {
    Remove-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "quantshift-primary" -RRType A -Force
}

# Add new record
Invoke-Command -ComputerName 10.92.0.10 -ScriptBlock {
    Add-DnsServerResourceRecord -ZoneName "cloudigan.net" -Name "quantshift-bot-primary" -A -IPv4Address "10.92.3.27"
}

# Verify
nslookup quantshift-bot-primary.cloudigan.net 10.92.0.10
```

**6b. Update Netbox IPAM**
1. Navigate to http://netbox.cloudigan.net
2. Search for "quantshift-primary" or "10.92.3.27"
3. Update Name: quantshift-bot-primary
4. Add Comment: "Renamed from quantshift-primary on 2026-02-23"
5. Save

#### Step 7: Verify Bot Services Restarted
```bash
# Check bot services are running
ssh prox "pct exec 100 -- systemctl status quantshift-equity"
ssh prox "pct exec 100 -- systemctl status quantshift-crypto"

# Check recent logs for errors
ssh prox "pct exec 100 -- journalctl -u quantshift-equity -n 50"
ssh prox "pct exec 100 -- journalctl -u quantshift-crypto -n 50"

# Verify Redis connection
ssh prox "pct exec 100 -- redis-cli ping"
# Expected: PONG
```

#### Step 8: Update Documentation
```bash
# Update infrastructure-spec.md and APP-MAP.md
grep -rn "quantshift-primary" documentation/ .cloudy-work/_cloudy-ops/context/
```

#### Step 9: Verify Monitoring
```bash
# Check Prometheus target
curl -s http://10.92.3.2:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.container=="ct100")'

# Verify label is still qs-primary (unchanged)
```

#### Step 10: Mark Complete
```bash
# Update progress tracker
```

---

## Post-Batch 1 Verification

### 1. Verify All DNS Records
```bash
# Test all new hostnames resolve
nslookup bni-toolkit-dev.cloudigan.net 10.92.0.10
nslookup quantshift-bot-standby.cloudigan.net 10.92.0.10
nslookup quantshift-bot-primary.cloudigan.net 10.92.0.10

# Test connectivity
ping -c 3 bni-toolkit-dev.cloudigan.net
ping -c 3 quantshift-bot-standby.cloudigan.net
ping -c 3 quantshift-bot-primary.cloudigan.net
```

### 2. Verify Netbox Updated
```bash
# Navigate to http://netbox.cloudigan.net
# Search for each new hostname
# Verify all 3 containers show new names
```

### 3. Verify Prometheus Monitoring
```bash
# Check all targets are up
curl -s http://10.92.3.2:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.container | startswith("ct1"))'
```

### 4. Update Documentation
```bash
# Commit all documentation changes
cd /Users/cory/Projects/homelab-nexus
git add documentation/ .cloudy-work/
git commit -m "docs: update hostnames for Batch 1 container renames

- CT119: sandbox-01 → bni-toolkit-dev
- CT101: quantshift-standby → quantshift-bot-standby
- CT100: quantshift-primary → quantshift-bot-primary"
git push origin main
```

---

## Troubleshooting

### Container Won't Start After Rename
```bash
# Check container logs
ssh prox "pct status 100"
ssh prox "journalctl -u pve-container@100 -n 50"

# Rollback if needed
ssh prox "pct stop 100"
ssh prox "pct set 100 --hostname quantshift-primary"
ssh prox "pct start 100"
```

### DNS Not Resolving
```bash
# Check DNS server
nslookup bni-toolkit-dev.cloudigan.net 10.92.0.10

# If fails, verify DC-01 DNS record exists
# RDP to DC-01, open DNS Manager, check cloudigan.net zone

# Flush DNS cache on workstation
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Service Not Starting
```bash
# Check service status
ssh prox "pct exec 100 -- systemctl status quantshift-equity"

# Check logs
ssh prox "pct exec 100 -- journalctl -u quantshift-equity -n 100"

# Restart service
ssh prox "pct exec 100 -- systemctl restart quantshift-equity"
```

---

## Success Criteria

**Batch 1 is complete when:**
- [ ] All 3 containers renamed in Proxmox
- [ ] All 3 containers boot successfully with new hostnames
- [ ] All 3 DNS records updated in DC-01
- [ ] All 3 Netbox entries updated
- [ ] All 3 containers resolve by new hostname
- [ ] All 3 containers accessible via SSH/ping
- [ ] QuantShift bot services running on CT100
- [ ] Prometheus monitoring shows all targets up
- [ ] Documentation updated and committed

**Estimated Total Time:** 1.5 - 2.5 hours

---

## Next Steps After Batch 1

**If Batch 1 successful:**
- Proceed to Batch 2 (Infrastructure Services)
- CT121: npm → nginx-proxy
- CT118: netbox-ipam → netbox
- CT150: monitor → monitoring-stack

**If issues encountered:**
- Document issues in TASK-STATE.md
- Rollback problematic containers
- Adjust procedure for Batch 2

---

**Last Updated:** 2026-02-23  
**Status:** Ready for Execution  
**Next:** Begin with CT119 (sandbox-01)
