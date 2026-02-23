# Container Rename Verification Process

**Purpose:** Ensure all systems are verified BEFORE and AFTER container renames  
**Last Updated:** 2026-02-23

---

## Overview

When renaming a container, we must verify and update **5 systems**:
1. **Proxmox** - Container configuration
2. **DC-01 DNS** - Active Directory DNS records
3. **NPM** - Nginx Proxy Manager (if app uses it)
4. **AdGuard** - DNS rewrites (if any exist)
5. **Netbox** - IPAM VM/IP records

---

## Required API Keys/Credentials

### Netbox API Token
**Required for:** Automated VM/IP lookups and updates

**How to get:**
1. Login to http://netbox.cloudigan.net (or http://10.92.3.18)
2. Click your username → API Tokens
3. Click "Add a token"
4. Name: "Container Rename Automation"
5. Copy the token
6. Set environment variable: `export NETBOX_TOKEN="your-token-here"`

### AdGuard Password
**Required for:** DNS rewrite checks and updates

**How to get:**
1. Use your AdGuard admin password
2. Set environment variables:
   ```bash
   export ADGUARD_USER="admin"
   export ADGUARD_PASS="your-password-here"
   ```

### NPM Credentials (Future)
**Required for:** Automated proxy host verification (not yet implemented)

**How to get:**
1. Use your NPM admin credentials
2. Set environment variables:
   ```bash
   export NPM_EMAIL="admin@example.com"
   export NPM_PASS="your-password-here"
   ```

---

## Verification Script

**Location:** `scripts/dns/verify-all-systems.sh`

**Usage:**
```bash
# Basic verification (manual NPM/AdGuard/Netbox checks)
./verify-all-systems.sh <ctid> <hostname> <ip>

# With API credentials (automated checks)
ADGUARD_PASS="password" NETBOX_TOKEN="token" \
  ./verify-all-systems.sh <ctid> <hostname> <ip>
```

**Example:**
```bash
# CT119 verification
ADGUARD_PASS="mypass" NETBOX_TOKEN="abc123" \
  ./verify-all-systems.sh 119 bni-toolkit-dev 10.92.3.12
```

---

## Step-by-Step Process

### BEFORE Rename

**1. Run Pre-Rename Verification**
```bash
cd /Users/cory/Projects/homelab-nexus/scripts/dns

# Verify current state
./verify-all-systems.sh <ctid> <old-hostname> <ip>
```

**2. Document Current State**
- Save verification output to file
- Screenshot NPM proxy hosts (if applicable)
- Screenshot Netbox VM entry
- Note any DNS rewrites in AdGuard

**3. Check for Dependencies**
- Review `container-rename-plan.md` for dependencies
- Check if app uses NPM (public domain)
- Check if Prometheus monitors this container
- Check if HAProxy routes to this container

---

### DURING Rename

**4. Execute Rename Script**
```bash
# Dry run first
./rename-container.sh --dry-run <ctid> <old-hostname> <new-hostname> <ip>

# If dry-run looks good, execute
./rename-container.sh <ctid> <old-hostname> <new-hostname> <ip>
```

**5. Manual Updates During Rename**

The script will prompt for:
- **Netbox update** - Update VM name via Web UI or API
- **NPM verification** - Check proxy hosts still work
- **AdGuard check** - Remove old DNS rewrites if any

---

### AFTER Rename

**6. Run Post-Rename Verification**
```bash
# Verify new state
./verify-all-systems.sh <ctid> <new-hostname> <ip>
```

**7. Verify Old Records Removed**
```bash
# Check old DNS record is gone
nslookup <old-hostname>.cloudigan.net 10.92.0.10
# Should return NXDOMAIN

# Check old AdGuard rewrite is gone (if applicable)
# Login to AdGuard → Filters → DNS rewrites
```

**8. Test Application**
```bash
# Test direct access
curl http://<ip>:<port>

# Test DNS access
curl http://<new-hostname>.cloudigan.net:<port>

# Test public access (if via NPM)
curl https://<public-domain>.cloudigan.net

# Test SSH access
ssh prox "pct exec <ctid> -- hostname"
```

**9. Update Documentation**
- Mark container complete in `container-rename-plan.md`
- Update `infrastructure-spec.md`
- Update control plane docs (APP-MAP.md, etc.)
- Commit changes to git

---

## Verification Checklist

### Proxmox ✓
- [ ] Container exists
- [ ] Container is running
- [ ] Hostname in config matches
- [ ] IP address in config matches
- [ ] Hostname inside container matches

### DC-01 DNS ✓
- [ ] New DNS record exists and resolves correctly
- [ ] Old DNS record removed (NXDOMAIN)
- [ ] DNS resolution works from Proxmox
- [ ] DNS resolution works from your Mac

### NPM (Manual) ✓
- [ ] Login to http://10.92.3.3:81
- [ ] Check "Proxy Hosts"
- [ ] Verify domains pointing to this container
- [ ] Verify Forward Hostname/IP is correct
- [ ] Verify Forward Port is correct
- [ ] Test public HTTPS access

### AdGuard (With Password) ✓
- [ ] AdGuard accessible
- [ ] Check for old hostname DNS rewrites (remove if found)
- [ ] Check for new hostname DNS rewrites (should not exist)
- [ ] Verify using DC-01 DNS directly

### Netbox (With Token) ✓
- [ ] Netbox API accessible
- [ ] VM found by new name
- [ ] IP address matches in Netbox
- [ ] Comments updated with rename date
- [ ] Old VM name not found

---

## Common Issues

### Issue: Netbox VM Not Found
**Cause:** VM name not updated in Netbox  
**Fix:** 
1. Login to http://netbox.cloudigan.net
2. Search for old hostname or IP address
3. Update VM name to new hostname
4. Add comment: "Renamed from <old> on <date>"

### Issue: DNS Not Resolving
**Cause:** DNS record not created or wrong IP  
**Fix:**
```bash
# Check DC-01 DNS
./update-dc01-dns.sh verify <new-hostname> <ip>

# If wrong, update it
./update-dc01-dns.sh update <new-hostname> <new-hostname> <correct-ip>
```

### Issue: NPM Proxy Not Working
**Cause:** NPM still pointing to old hostname or wrong IP  
**Fix:**
1. Login to NPM
2. Edit proxy host
3. Update Forward Hostname/IP to new IP
4. Save and test

### Issue: AdGuard Rewrite Conflicts
**Cause:** Old DNS rewrite still exists  
**Fix:**
```bash
# Remove old rewrite
./update-adguard-dns.sh remove <old-hostname> <ip>
```

---

## Automation Levels

### Level 1: Manual (Current for NPM)
- Run verification script
- Manually check NPM Web UI
- Manually update Netbox Web UI
- Manually check AdGuard Web UI

### Level 2: Semi-Automated (With Credentials)
- Run verification script with ADGUARD_PASS and NETBOX_TOKEN
- Script checks AdGuard and Netbox automatically
- Still manually verify NPM

### Level 3: Fully Automated (Future)
- All systems checked and updated via API
- No manual steps required
- Requires NPM API integration

---

## Example: Complete CT119 Verification

### Before Rename
```bash
# Verify current state
./verify-all-systems.sh 119 sandbox-01 10.92.3.12

# Output shows:
# - Proxmox: sandbox-01, 10.92.3.12 ✓
# - DNS: sandbox-01.cloudigan.net → 10.92.3.12 ✓
# - NPM: Manual check needed
# - AdGuard: No rewrites ✓
# - Netbox: VM found as sandbox-01 ✓
```

### Execute Rename
```bash
./rename-container.sh 119 sandbox-01 bni-toolkit-dev 10.92.3.12
# Script prompts for Netbox update - do it via Web UI
```

### After Rename
```bash
# Verify new state
NETBOX_TOKEN="token" ./verify-all-systems.sh 119 bni-toolkit-dev 10.92.3.12

# Output shows:
# - Proxmox: bni-toolkit-dev, 10.92.3.12 ✓
# - DNS: bni-toolkit-dev.cloudigan.net → 10.92.3.12 ✓
# - NPM: Manual check needed
# - AdGuard: No rewrites ✓
# - Netbox: VM found as bni-toolkit-dev ✓

# Verify old DNS gone
nslookup sandbox-01.cloudigan.net 10.92.0.10
# → NXDOMAIN ✓
```

---

## Required Credentials Summary

**Set these in your shell for automated checks:**

```bash
# Add to ~/.zshrc or run before each rename
export ADGUARD_USER="admin"
export ADGUARD_PASS="your-adguard-password"
export NETBOX_TOKEN="your-netbox-api-token"

# Future (not yet implemented)
export NPM_EMAIL="admin@example.com"
export NPM_PASS="your-npm-password"
```

---

**Status:** Ready for use - requires API tokens for full automation
