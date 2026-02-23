# DNS Automation Setup Guide

This guide covers setting up automated DNS management for container renames using DC-01 (Windows Server) and AdGuard Home.

---

## Prerequisites

### Required
- SSH access to Proxmox host (`prox`)
- Windows Server DC-01 at 10.92.0.10
- AdGuard Home at 10.92.3.11 (optional but recommended)
- Netbox IPAM at 10.92.3.18

### Tools
- `bash` (macOS/Linux)
- `ssh` client
- `curl` (for AdGuard API)
- `jq` (optional, for better JSON formatting)

---

## Part 1: Install OpenSSH Server on DC-01 (Windows Server)

### Option A: Via PowerShell (Recommended)

1. **RDP to DC-01** (10.92.0.10)

2. **Open PowerShell as Administrator**

3. **Check if OpenSSH Server is available:**
   ```powershell
   Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
   ```

4. **Install OpenSSH Server:**
   ```powershell
   Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
   ```

5. **Start and enable SSH service:**
   ```powershell
   Start-Service sshd
   Set-Service -Name sshd -StartupType 'Automatic'
   ```

6. **Configure Windows Firewall (if needed):**
   ```powershell
   # Check if firewall rule exists
   Get-NetFirewallRule -Name *ssh*
   
   # If not, create it
   New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
   ```

7. **Set PowerShell as default shell (important for DNS scripts):**
   ```powershell
   New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
   ```

### Option B: Via Server Manager GUI

1. RDP to DC-01
2. Open **Server Manager**
3. Click **Manage** → **Add Roles and Features**
4. Click **Next** until you reach **Features**
5. Expand **OpenSSH** and select **OpenSSH Server**
6. Click **Next** and **Install**
7. After installation, open **Services** (services.msc)
8. Find **OpenSSH SSH Server**
9. Right-click → **Properties**
10. Set **Startup type** to **Automatic**
11. Click **Start**

---

## Part 2: Configure SSH Key Authentication

### On Your Mac/Linux Workstation

1. **Generate SSH key (if you don't have one):**
   ```bash
   ssh-keygen -t rsa -b 4096 -C "homelab-automation"
   # Press Enter to accept default location (~/.ssh/id_rsa)
   # Set a passphrase or leave empty
   ```

2. **Copy public key to DC-01:**
   ```bash
   # Method 1: Using ssh-copy-id (if available)
   ssh-copy-id Administrator@10.92.0.10
   
   # Method 2: Manual copy
   cat ~/.ssh/id_rsa.pub
   # Copy the output
   ```

3. **If using Method 2, on DC-01 (via RDP or SSH with password):**
   ```powershell
   # Create .ssh directory in Administrator's profile
   New-Item -ItemType Directory -Force -Path C:\Users\Administrator\.ssh
   
   # Create authorized_keys file
   # Paste your public key into this file:
   notepad C:\Users\Administrator\.ssh\authorized_keys
   
   # Set correct permissions
   icacls C:\Users\Administrator\.ssh\authorized_keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
   ```

4. **Test SSH connection from your workstation:**
   ```bash
   ssh Administrator@10.92.0.10
   # Should connect without password
   
   # Test PowerShell command
   ssh Administrator@10.92.0.10 "powershell.exe -Command 'Get-Date'"
   ```

---

## Part 3: Test DC-01 DNS Script

1. **Make script executable:**
   ```bash
   cd /Users/cory/Projects/homelab-nexus/scripts/dns
   chmod +x update-dc01-dns.sh
   ```

2. **Test SSH connection:**
   ```bash
   ./update-dc01-dns.sh test
   ```
   Expected output:
   ```
   ℹ Testing SSH connection to DC-01 (10.92.0.10)...
   ✓ SSH connection to DC-01 successful
   ```

3. **List existing DNS records:**
   ```bash
   ./update-dc01-dns.sh list
   ```

4. **Test adding a record (dry run):**
   ```bash
   # Add a test record
   ./update-dc01-dns.sh add test-hostname 10.92.3.99
   
   # Verify it was added
   ./update-dc01-dns.sh verify test-hostname 10.92.3.99
   
   # Remove test record
   ./update-dc01-dns.sh remove test-hostname
   ```

---

## Part 4: Configure AdGuard Home API Access

### Get AdGuard Credentials

1. **Navigate to AdGuard Web UI:**
   ```
   http://10.92.3.11:3000
   ```

2. **Login with admin credentials**

3. **Note your username and password** (you'll need these for the scripts)

### Test AdGuard Script

1. **Make script executable:**
   ```bash
   chmod +x update-adguard-dns.sh
   ```

2. **Test connection:**
   ```bash
   ./update-adguard-dns.sh test
   ```

3. **Set credentials (optional - script will prompt if not set):**
   ```bash
   export ADGUARD_USER="admin"
   export ADGUARD_PASS="your-password"
   ```

4. **List existing DNS rewrites:**
   ```bash
   ./update-adguard-dns.sh list
   ```

5. **Test adding a rewrite:**
   ```bash
   # Add test rewrite
   ./update-adguard-dns.sh add test-hostname 10.92.3.99
   
   # Verify
   ./update-adguard-dns.sh verify test-hostname
   
   # Remove
   ./update-adguard-dns.sh remove test-hostname 10.92.3.99
   ```

---

## Part 5: Test Master Rename Script

1. **Make script executable:**
   ```bash
   chmod +x rename-container.sh
   ```

2. **Run dry-run test (no changes made):**
   ```bash
   ./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13
   ```

3. **Review the output** - it should show all steps that would be performed

4. **If dry-run looks good, run actual rename:**
   ```bash
   ./rename-container.sh 119 sandbox-01 bni-toolkit-dev 10.92.3.13
   ```

---

## Troubleshooting

### SSH Connection Issues

**Problem:** Cannot connect to DC-01 via SSH

**Solutions:**
1. Verify OpenSSH Server is running:
   ```powershell
   Get-Service sshd
   ```

2. Check firewall:
   ```powershell
   Get-NetFirewallRule -Name *ssh*
   ```

3. Test from Proxmox host:
   ```bash
   ssh prox
   ssh Administrator@10.92.0.10
   ```

4. Check SSH logs on DC-01:
   ```powershell
   Get-EventLog -LogName Security -Newest 50 | Where-Object {$_.EventID -eq 4624}
   ```

### PowerShell Command Fails

**Problem:** SSH connects but PowerShell commands fail

**Solutions:**
1. Verify default shell is PowerShell:
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell
   ```

2. Test PowerShell execution:
   ```bash
   ssh Administrator@10.92.0.10 "powershell.exe -Command 'Get-Date'"
   ```

3. Check PowerShell execution policy:
   ```powershell
   Get-ExecutionPolicy
   # Should be RemoteSigned or Unrestricted
   ```

### DNS Cmdlet Not Found

**Problem:** `Add-DnsServerResourceRecord` not recognized

**Solutions:**
1. Verify DNS Server role is installed:
   ```powershell
   Get-WindowsFeature -Name DNS
   ```

2. Import DNS module:
   ```powershell
   Import-Module DnsServer
   ```

3. Check if running on Domain Controller:
   ```powershell
   Get-ADDomainController
   ```

### AdGuard API Authentication Fails

**Problem:** 401 Unauthorized error

**Solutions:**
1. Verify credentials are correct
2. Check AdGuard is accessible:
   ```bash
   curl http://10.92.3.11:3000/control/status
   ```

3. Try logging in via Web UI to verify credentials

---

## Security Considerations

### SSH Key Security
- Use strong passphrase for SSH key
- Restrict SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
- Consider using separate key for automation

### AdGuard Credentials
- Don't commit credentials to git
- Use environment variables: `ADGUARD_USER`, `ADGUARD_PASS`
- Consider creating dedicated API user in AdGuard

### Windows Server Security
- Limit SSH access to specific users/groups
- Enable SSH logging for audit trail
- Consider using certificate-based authentication

---

## Script Reference

### update-dc01-dns.sh

**Purpose:** Manage DNS A records on Windows Server DC-01

**Commands:**
```bash
./update-dc01-dns.sh add <hostname> <ip>
./update-dc01-dns.sh remove <hostname>
./update-dc01-dns.sh update <old> <new> <ip>
./update-dc01-dns.sh verify <hostname> [ip]
./update-dc01-dns.sh list
./update-dc01-dns.sh test
```

**Configuration:**
- DC-01 Host: 10.92.0.10
- User: Administrator
- DNS Zone: cloudigan.net
- SSH Key: ~/.ssh/id_rsa

### update-adguard-dns.sh

**Purpose:** Manage DNS rewrites in AdGuard Home

**Commands:**
```bash
./update-adguard-dns.sh add <hostname> <ip>
./update-adguard-dns.sh remove <hostname> <ip>
./update-adguard-dns.sh update <old> <new> <ip>
./update-adguard-dns.sh verify <hostname>
./update-adguard-dns.sh list
./update-adguard-dns.sh test
```

**Configuration:**
- AdGuard URL: http://10.92.3.11:3000
- Domain: cloudigan.net
- Credentials: Via environment or prompt

### rename-container.sh

**Purpose:** Orchestrate full container rename

**Usage:**
```bash
./rename-container.sh [--dry-run] <ctid> <old> <new> <ip>
```

**Steps:**
1. Verify container status
2. Stop container
3. Rename in Proxmox
4. Start container
5. Verify hostname
6. Update DC-01 DNS
7. Update AdGuard DNS (if exists)
8. Update Netbox (manual prompt)
9. Verify DNS resolution
10. Show summary

---

## Next Steps

After setup is complete:

1. **Test with CT119 (sandbox-01):**
   ```bash
   ./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13
   ```

2. **If dry-run successful, execute:**
   ```bash
   ./rename-container.sh 119 sandbox-01 bni-toolkit-dev 10.92.3.13
   ```

3. **Proceed with remaining Batch 1 containers:**
   - CT101: quantshift-standby → quantshift-bot-standby
   - CT100: quantshift-primary → quantshift-bot-primary

4. **After Batch 1, continue to Batch 2 and 3**

---

**Last Updated:** 2026-02-23  
**Status:** Ready for Testing
