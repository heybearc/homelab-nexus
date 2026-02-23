# DNS Automation Setup Status

**Last Updated:** 2026-02-23 2:05 PM

---

## ✅ What's Working

1. **DC-01 SSH Access:** Password authentication works with `cory@cloudigan.com`
2. **Scripts Created:** All 3 automation scripts are ready
3. **Scripts Updated:** Using `cory@cloudigan.com` instead of Administrator
4. **PubkeyAuthentication Enabled:** On DC-01 (sshd_config updated)
5. **SSH Key Installed:** In `C:\Users\cory\.ssh\authorized_keys`

---

## ⚠️ Current Issue

**SSH Key Authentication Not Working**

Despite:
- PubkeyAuthentication enabled in sshd_config
- SSH key properly installed in authorized_keys
- Correct file permissions set
- sshd service restarted

SSH key auth still fails with "Permission denied (publickey,password,keyboard-interactive)"

**Likely Cause:** Windows OpenSSH has strict requirements for key format or permissions that we haven't met yet.

---

## 🎯 Two Options to Proceed

### Option 1: Use Password Authentication (Works Now)

The scripts will work with password authentication. You'll be prompted for the password when DNS updates are needed.

**Pros:**
- Works immediately
- No additional setup needed
- Scripts are functional

**Cons:**
- Password prompt for each DNS operation
- Less convenient for automation

**To Use:**
```bash
cd /Users/cory/Projects/homelab-nexus/scripts/dns

# Test (will prompt for password)
./update-dc01-dns.sh list

# Run container rename (will prompt for password)
./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13
```

---

### Option 2: Fix SSH Key Auth (Requires Investigation)

We need to troubleshoot why Windows OpenSSH isn't accepting the key.

**Possible Issues:**
1. Key format (OpenSSH vs PuTTY format)
2. Line endings in authorized_keys (Windows CRLF vs Unix LF)
3. Additional permissions on .ssh directory
4. Windows OpenSSH logs need checking

**To Investigate:**
```powershell
# On DC-01, check SSH logs
Get-EventLog -LogName Application -Source sshd -Newest 10

# Check authorized_keys format
Get-Content C:\Users\cory\.ssh\authorized_keys | Format-Hex

# Verify permissions
icacls C:\Users\cory\.ssh\authorized_keys
```

---

## 📝 Recommendation

**Proceed with Option 1 (Password Auth) for now:**

1. The scripts are functional with password authentication
2. You can complete the container renames today
3. We can troubleshoot SSH key auth separately later

**The rename process will work like this:**
- Script prompts for DC-01 password once per container
- All other operations (Proxmox, verification) are automated
- Still saves significant time vs manual process

---

## 🚀 Next Steps

**To proceed with container renames:**

```bash
cd /Users/cory/Projects/homelab-nexus/scripts/dns

# Dry run first container (will prompt for password)
./rename-container.sh --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13

# If dry-run looks good, execute
./rename-container.sh 119 sandbox-01 bni-toolkit-dev 10.92.3.13
```

**Note:** AdGuard script won't work from your Mac (different network), but the rename script handles this gracefully - it checks if AdGuard DNS rewrites exist and only updates if found.

---

## 📊 What We Accomplished

- ✅ Created 3 automation scripts (DC-01, AdGuard, master rename)
- ✅ Configured DC-01 for SSH access with domain account
- ✅ Enabled PubkeyAuthentication on DC-01
- ✅ Installed SSH key on DC-01
- ✅ Updated scripts to use `cory@cloudigan.com`
- ✅ Verified password authentication works
- ⏳ SSH key auth troubleshooting pending

---

**Ready to proceed with password authentication?**
