# CT119 Rename - Complete Status Report

**Date:** 2026-02-23  
**Container:** CT119  
**Old Name:** sandbox-01  
**New Name:** bni-toolkit-dev  
**IP:** 10.92.3.12

---

## ✅ VERIFIED - Working Correctly

### 1. Proxmox Configuration
- **CTID:** 119 ✅
- **Hostname:** bni-toolkit-dev ✅
- **IP:** 10.92.3.12 ✅
- **Network:** vmbr0923 ✅

### 2. DNS Records (DC-01)
- **New internal record:** bni-toolkit-dev.cloudigan.net → 10.92.3.12 ✅
- **Public record:** bnitoolkit.cloudigan.net → 10.92.3.3 (NPM) ✅
- **Old record removed:** sandbox-01.cloudigan.net (NXDOMAIN) ✅

### 3. Application Status
- **PM2 process:** bni-toolkit (online) ✅
- **Port:** 3001 ✅
- **Database:** Connected to 10.92.3.21 ✅
- **Public access:** https://bnitoolkit.cloudigan.net (working) ✅

---

## ⏳ NEEDS MANUAL VERIFICATION

### 4. NPM (Nginx Proxy Manager)
**URL:** http://10.92.3.3:81  
**Action Required:**
1. Login to NPM
2. Go to "Proxy Hosts"
3. Find entry for: bnitoolkit.cloudigan.net
4. Verify "Forward Hostname/IP" is: 10.92.3.12
5. Verify "Forward Port" is: 3001
6. **No changes should be needed** - just verify it's correct

**Expected Configuration:**
- Domain: bnitoolkit.cloudigan.net
- Scheme: http
- Forward Hostname/IP: 10.92.3.12
- Forward Port: 3001
- SSL: Let's Encrypt (already configured)

---

## ⏳ NEEDS MANUAL VERIFICATION

### 5. AdGuard Home
**URL:** http://10.92.3.11:3000  
**Action Required:**
1. Login to AdGuard
2. Go to "Filters" → "DNS rewrites"
3. Search for: sandbox-01
4. If found, remove it
5. Search for: bni-toolkit
6. Verify no rewrite exists (should use DC-01 DNS directly)

**Expected:** No DNS rewrites for this container

---

## ❌ NOT DONE - REQUIRED

### 6. Netbox IPAM
**URL:** http://netbox.cloudigan.net or http://10.92.3.18  
**Action Required:**
1. Login to Netbox
2. Search for: "sandbox-01" OR "CT119" OR "10.92.3.12"
3. Find the VM/Device entry
4. Update the following fields:
   - **Name:** bni-toolkit-dev
   - **Comments:** Add "Renamed from sandbox-01 on 2026-02-23"
   - **Description:** Update if needed
5. Save changes

**This is CRITICAL for IPAM accuracy**

---

## Testing Performed

### DNS Resolution
```bash
✅ nslookup bni-toolkit-dev.cloudigan.net 10.92.0.10
   → 10.92.3.12

✅ nslookup bnitoolkit.cloudigan.net 10.92.0.10
   → 10.92.3.3 (NPM)

✅ nslookup sandbox-01.cloudigan.net 10.92.0.10
   → NXDOMAIN (correctly removed)
```

### Network Connectivity
```bash
✅ ping bni-toolkit-dev.cloudigan.net
   → 64 bytes from 10.92.3.12

✅ curl http://10.92.3.12:3001
   → BNI Toolkit homepage loads

✅ curl https://bnitoolkit.cloudigan.net
   → BNI Toolkit homepage loads (via NPM with SSL)
```

### Application Health
```bash
✅ ssh prox "pct exec 119 -- hostname"
   → bni-toolkit-dev

✅ ssh prox "pct exec 119 -- pm2 list"
   → bni-toolkit (online, 0 restarts)
```

---

## Summary

### Completed Automatically ✅
1. Container renamed in Proxmox
2. DNS records updated on DC-01
3. Old DNS record removed
4. Application running successfully
5. Public access working via NPM

### Requires Manual Action ⏳
1. **NPM:** Verify proxy host configuration (should already be correct)
2. **AdGuard:** Check for old DNS rewrites (if any)
3. **Netbox:** Update VM/Device name ❌ **CRITICAL**

---

## Next Steps

**Before proceeding to CT101:**
1. ✅ Complete Netbox update for CT119
2. ✅ Verify NPM configuration
3. ✅ Check AdGuard (if applicable)
4. ✅ Document any findings

**Then:**
- Proceed with CT101: quantshift-standby → quantshift-bot-standby
- Use same verification process

---

**Status:** MOSTLY COMPLETE - Netbox update required before moving to next container
