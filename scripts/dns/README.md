# DNS Management Scripts for Container Renames

Automated DNS management for Proxmox container renames across DC-01 (Windows Server Active Directory) and AdGuard Home.

---

## Overview

These scripts automate the DNS update process when renaming Proxmox LXC containers, eliminating manual DNS record updates across multiple systems.

### What's Included

1. **`update-dc01-dns.sh`** - Manage Windows Server Active Directory DNS via SSH
2. **`update-adguard-dns.sh`** - Manage AdGuard Home DNS rewrites via API
3. **`rename-container.sh`** - Master orchestration script for full container renames
4. **`SETUP.md`** - Detailed setup instructions

---

## Quick Start

### 1. Setup (One-Time)

**Install OpenSSH Server on DC-01:**
```powershell
# On DC-01 (Windows Server), run as Administrator:
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Set PowerShell as default shell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
```

**Configure SSH key authentication:**
```bash
# On your workstation:
ssh-copy-id Administrator@10.92.0.10
```

**Make scripts executable:**
```bash
cd /Users/cory/Projects/homelab-nexus/scripts/dns
chmod +x *.sh
```

**Test connectivity:**
```bash
./update-dc01-dns.sh test
./update-adguard-dns.sh test
```

See `SETUP.md` for detailed instructions.

---

### 2. Rename a Container

**Dry run (recommended first):**
```bash
./rename-container.sh --dry-run <ctid> <old-hostname> <new-hostname> <ip>
```

**Example:**
```bash
./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13
```

**Execute rename:**
```bash
./rename-container.sh 119 sandbox-01 bni-toolkit-dev 10.92.3.13
```

---

## Script Details

### update-dc01-dns.sh

Manages DNS A records on Windows Server Active Directory DNS.

**Usage:**
```bash
./update-dc01-dns.sh <command> [arguments]
```

**Commands:**
- `add <hostname> <ip>` - Add new DNS A record
- `remove <hostname>` - Remove DNS A record
- `update <old> <new> <ip>` - Update record (remove old, add new)
- `verify <hostname> [ip]` - Verify record exists
- `list` - List all A records
- `test` - Test SSH connection

**Examples:**
```bash
# Add record
./update-dc01-dns.sh add bni-toolkit-dev 10.92.3.13

# Update record
./update-dc01-dns.sh update sandbox-01 bni-toolkit-dev 10.92.3.13

# Verify record
./update-dc01-dns.sh verify bni-toolkit-dev 10.92.3.13

# List all records
./update-dc01-dns.sh list
```

**Requirements:**
- OpenSSH Server on DC-01
- SSH key authentication configured
- PowerShell DNS cmdlets (default on Windows Server)

---

### update-adguard-dns.sh

Manages DNS rewrites in AdGuard Home via API.

**Usage:**
```bash
./update-adguard-dns.sh <command> [arguments]
```

**Commands:**
- `add <hostname> <ip>` - Add DNS rewrite
- `remove <hostname> <ip>` - Remove DNS rewrite
- `update <old> <new> <ip>` - Update rewrite
- `verify <hostname>` - Verify rewrite exists
- `list` - List all rewrites
- `test` - Test API connection

**Examples:**
```bash
# Add rewrite
./update-adguard-dns.sh add bni-toolkit-dev 10.92.3.13

# Update rewrite
./update-adguard-dns.sh update sandbox-01 bni-toolkit-dev 10.92.3.13

# List all rewrites
./update-adguard-dns.sh list
```

**Authentication:**
```bash
# Set credentials via environment (optional)
export ADGUARD_USER="admin"
export ADGUARD_PASS="your-password"

# Or script will prompt for credentials
```

**Requirements:**
- AdGuard Home running and accessible
- Admin credentials

---

### rename-container.sh

Master orchestration script that performs complete container rename.

**Usage:**
```bash
./rename-container.sh [--dry-run] <ctid> <old-hostname> <new-hostname> <ip>
```

**Steps Performed:**
1. ✓ Pre-rename verification (container status, hostname)
2. ✓ Stop container
3. ✓ Rename in Proxmox
4. ✓ Start container
5. ✓ Verify hostname inside container
6. ✓ Update DC-01 DNS (remove old, add new)
7. ✓ Update AdGuard DNS (if rewrite exists)
8. ✓ Update Netbox IPAM (manual prompt)
9. ✓ Verify DNS resolution
10. ✓ Show summary

**Examples:**
```bash
# Dry run (no changes)
./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13

# Execute rename
./rename-container.sh 119 sandbox-01 bni-toolkit-dev 10.92.3.13
```

**Rollback:**
If rename fails, script automatically attempts rollback:
- Reverts Proxmox hostname
- Reverts DC-01 DNS record
- Restarts container with old name

**Requirements:**
- All requirements from DC-01 and AdGuard scripts
- SSH access to Proxmox host
- Netbox access for manual update

---

## Configuration

### DC-01 DNS Script
```bash
DC01_HOST="10.92.0.10"
DC01_USER="Administrator"
DNS_ZONE="cloudigan.net"
SSH_KEY="${HOME}/.ssh/id_rsa"
```

### AdGuard Script
```bash
ADGUARD_HOST="10.92.3.11"
ADGUARD_PORT="3000"
DNS_DOMAIN="cloudigan.net"
```

### Master Rename Script
```bash
PROXMOX_HOST="prox"
NETBOX_URL="http://10.92.3.18"
```

---

## Batch 1 Rename Commands

Ready-to-use commands for Batch 1 containers:

### CT119: sandbox-01 → bni-toolkit-dev
```bash
# Dry run
./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13

# Execute
./rename-container.sh 119 sandbox-01 bni-toolkit-dev 10.92.3.13
```

### CT101: quantshift-standby → quantshift-bot-standby
```bash
# Dry run
./rename-container.sh --dry-run 101 quantshift-standby quantshift-bot-standby 10.92.3.28

# Execute
./rename-container.sh 101 quantshift-standby quantshift-bot-standby 10.92.3.28
```

### CT100: quantshift-primary → quantshift-bot-primary
```bash
# Dry run
./rename-container.sh --dry-run 100 quantshift-primary quantshift-bot-primary 10.92.3.27

# Execute
./rename-container.sh 100 quantshift-primary quantshift-bot-primary 10.92.3.27
```

---

## Troubleshooting

### SSH Connection Fails
```bash
# Test SSH to DC-01
ssh Administrator@10.92.0.10

# Check OpenSSH service on DC-01
Get-Service sshd

# Verify firewall allows SSH
Get-NetFirewallRule -Name *ssh*
```

### PowerShell Commands Fail
```bash
# Verify default shell is PowerShell
ssh Administrator@10.92.0.10 "powershell.exe -Command 'Get-Date'"

# Check PowerShell execution policy
Get-ExecutionPolicy
```

### DNS Cmdlet Not Found
```powershell
# Verify DNS Server role installed
Get-WindowsFeature -Name DNS

# Import DNS module
Import-Module DnsServer
```

### AdGuard API Fails
```bash
# Test AdGuard connectivity
curl http://10.92.3.11:3000/control/status

# Verify credentials
# Login via Web UI: http://10.92.3.11:3000
```

---

## Security Notes

- SSH keys should be protected with strong passphrase
- AdGuard credentials should not be committed to git
- Use environment variables for sensitive data
- Consider dedicated automation user for AdGuard
- Enable SSH logging on DC-01 for audit trail

---

## Next Steps

1. **Complete setup** - Follow `SETUP.md`
2. **Test scripts** - Run dry-run mode first
3. **Execute Batch 1** - Rename 3 low-risk containers
4. **Verify results** - Check DNS resolution, services
5. **Continue to Batch 2** - Infrastructure containers
6. **Complete Batch 3** - Production apps

---

## Related Documentation

- `SETUP.md` - Detailed setup instructions
- `../../documentation/container-rename-plan.md` - Full rename plan
- `../../documentation/dns-management-for-renames.md` - DNS strategy
- `../../documentation/phase3-execution-guide.md` - Execution guide

---

**Created:** 2026-02-23  
**Status:** Ready for Use  
**Tested:** Pending initial test
