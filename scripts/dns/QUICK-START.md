# Quick Start Guide - DNS Automation

## Current Status

✅ **DC-01 SSH:** Accessible with password authentication  
❌ **DC-01 SSH Key:** Not configured (PubkeyAuthentication disabled in sshd_config)  
✅ **AdGuard Home:** Accessible from Proxmox (10.92.3.11)  
❌ **AdGuard Home:** Not accessible from your Mac (different network)

---

## Option 1: Enable SSH Key Auth on DC-01 (Recommended)

### Via RDP (Easiest)

1. **RDP to DC-01** (10.92.0.10)

2. **Open PowerShell as Administrator**

3. **Edit sshd_config:**
   ```powershell
   notepad C:\ProgramData\ssh\sshd_config
   ```

4. **Find and uncomment this line:**
   ```
   #PubkeyAuthentication yes
   ```
   Change to:
   ```
   PubkeyAuthentication yes
   ```

5. **Save and close notepad**

6. **Restart SSH service:**
   ```powershell
   Restart-Service sshd
   ```

7. **Test from your Mac:**
   ```bash
   ssh Administrator@10.92.0.10 "powershell.exe -Command 'Write-Host test'"
   # Should connect without password
   ```

---

## Option 2: Use Scripts from Proxmox (Works Now)

Since AdGuard is only accessible from Proxmox network, run the scripts from Proxmox instead of your Mac.

### Copy Scripts to Proxmox

```bash
# From your Mac
scp -r scripts/dns prox:/root/homelab-scripts/
```

### Run from Proxmox

```bash
# SSH to Proxmox
ssh prox

# Navigate to scripts
cd /root/homelab-scripts/dns

# Test DC-01 (will prompt for password)
./update-dc01-dns.sh test

# Test AdGuard (will work from Proxmox)
./update-adguard-dns.sh test

# Run container rename
./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13
```

---

## Option 3: Temporary - Use Password Auth

The scripts will work with password authentication, but you'll need to enter the password for each DC-01 operation.

### Test Now (From Your Mac)

```bash
cd /Users/cory/Projects/homelab-nexus/scripts/dns

# This will prompt for password but should work
ssh Administrator@10.92.0.10 "powershell.exe -Command 'Get-DnsServerResourceRecord -ZoneName cloudigan.net -RRType A | Select-Object -First 5'"
```

---

## Recommended Approach

**For today:**
1. Enable PubkeyAuthentication on DC-01 (5 minutes via RDP)
2. Test SSH key auth works
3. Run scripts from your Mac

**Alternative:**
1. Copy scripts to Proxmox
2. Run everything from Proxmox (AdGuard will work, DC-01 will prompt for password)

---

## Next Steps After SSH is Working

```bash
# Test DC-01 DNS script
./update-dc01-dns.sh list

# Test adding a record
./update-dc01-dns.sh add test-host 10.92.3.99
./update-dc01-dns.sh verify test-host 10.92.3.99
./update-dc01-dns.sh remove test-host

# Test AdGuard (from Proxmox only)
./update-adguard-dns.sh list

# Run dry-run rename
./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13

# If dry-run looks good, execute
./rename-container.sh 119 sandbox-01 bni-toolkit-dev 10.92.3.13
```

---

## What You Need to Decide

**Choose one:**

**A) Fix SSH key auth now** (5 min via RDP)
- Pros: Scripts work from your Mac, no password prompts
- Cons: Requires RDP session to DC-01

**B) Run from Proxmox** (works immediately)
- Pros: No DC-01 changes needed, AdGuard accessible
- Cons: Need to SSH to Proxmox first, still need DC-01 password

**C) Use password auth for now** (works but tedious)
- Pros: No changes needed
- Cons: Password prompt for every DC-01 operation

---

**Which option would you like to proceed with?**
