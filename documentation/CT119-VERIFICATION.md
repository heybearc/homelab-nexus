# CT119 Complete Verification Checklist

**Container:** CT119  
**Old Name:** sandbox-01  
**New Name:** bni-toolkit-dev  
**Date:** 2026-02-23

---

## 1. Proxmox Configuration

**CTID:** 119 ✅  
**Hostname:** bni-toolkit-dev ✅  
**IP Address:** 10.92.3.12 ✅  
**Network:** vmbr0923 (services network) ✅  
**Gateway:** 10.92.3.1 ✅

```bash
$ ssh prox "pct config 119 | grep -E 'hostname|net0'"
hostname: bni-toolkit-dev
net0: name=eth0,bridge=vmbr0923,gw=10.92.3.1,hwaddr=BC:24:11:5E:4B:66,ip=10.92.3.12/24,type=veth
```

---

## 2. DNS Records (DC-01)

### Internal Access Record
**Hostname:** bni-toolkit-dev.cloudigan.net  
**IP:** 10.92.3.12  
**Status:** ✅ VERIFIED

```bash
$ nslookup bni-toolkit-dev.cloudigan.net 10.92.0.10
Name:   bni-toolkit-dev.cloudigan.net
Address: 10.92.3.12
```

### Public Access Record (via NPM)
**Hostname:** bnitoolkit.cloudigan.net  
**IP:** 10.92.3.3 (NPM)  
**Status:** ✅ VERIFIED (already existed, no change needed)

```bash
$ nslookup bnitoolkit.cloudigan.net 10.92.0.10
Name:   bnitoolkit.cloudigan.net
Address: 10.92.3.3
```

### Old Record Cleanup
**Old Hostname:** sandbox-01.cloudigan.net  
**Status:** ⚠️ NEEDS VERIFICATION - was it removed?

---

## 3. NPM (Nginx Proxy Manager) - 10.92.3.3

**Public Domain:** bnitoolkit.cloudigan.net  
**Backend:** 10.92.3.12:3001  
**Status:** ✅ WORKING (HTTPS site loads successfully)

**Test:**
```bash
$ curl -s https://bnitoolkit.cloudigan.net | grep "BNI Chapter Toolkit"
✅ Returns BNI Chapter Toolkit homepage
```

**Action Needed:** ❓ Verify NPM proxy host configuration hasn't changed

---

## 4. AdGuard Home - 10.92.3.11

**DNS Rewrites:** Need to check if any exist for sandbox-01 or bni-toolkit-dev

**Status:** ⏳ NEEDS VERIFICATION

**Action Needed:**
- Check if sandbox-01 DNS rewrite exists (should be removed)
- Check if bni-toolkit-dev DNS rewrite needed (probably not)

---

## 5. Netbox IPAM - 10.92.3.18

**Container Entry:** CT119  
**Status:** ❌ NOT UPDATED YET

**Action Needed:**
1. Login to http://netbox.cloudigan.net
2. Search for CT119 or 10.92.3.12 or "sandbox-01"
3. Update VM/Device name to: bni-toolkit-dev
4. Update description/notes
5. Add comment: "Renamed from sandbox-01 on 2026-02-23"

---

## 6. Application Status

**PM2 Process:** bni-toolkit ✅  
**Port:** 3001 ✅  
**Status:** online ✅  
**Database:** bni_toolkit @ 10.92.3.21 ✅

```bash
$ ssh prox "pct exec 119 -- pm2 list"
│ 0  │ bni-toolkit    │ online   │ 0%       │ 67.7mb   │
```

---

## Summary of Actions Needed

### ✅ Completed
1. Container renamed in Proxmox
2. Internal DNS record created (bni-toolkit-dev.cloudigan.net → 10.92.3.12)
3. Public DNS record verified (bnitoolkit.cloudigan.net → 10.92.3.3)
4. Application running successfully

### ⏳ Needs Verification
1. **DC-01 DNS:** Verify sandbox-01.cloudigan.net was removed
2. **NPM:** Verify proxy host configuration (bnitoolkit.cloudigan.net → 10.92.3.12:3001)
3. **AdGuard:** Check for any DNS rewrites that need updating
4. **Netbox:** Update VM/Device name from sandbox-01 to bni-toolkit-dev

### ❌ Not Done
1. **Netbox IPAM update** - MUST BE DONE MANUALLY

---

## Verification Commands

### Check DNS Records
```bash
# Check new record
nslookup bni-toolkit-dev.cloudigan.net 10.92.0.10

# Check old record (should fail)
nslookup sandbox-01.cloudigan.net 10.92.0.10

# Check public record
nslookup bnitoolkit.cloudigan.net 10.92.0.10
```

### Check NPM
```bash
# Access NPM UI
open http://10.92.3.3:81

# Check proxy hosts for bnitoolkit.cloudigan.net
# Verify forward hostname/IP is 10.92.3.12 and port 3001
```

### Check AdGuard
```bash
# Access AdGuard UI
open http://10.92.3.11:3000

# Go to Filters → DNS rewrites
# Search for sandbox-01 or bni-toolkit
```

### Check Netbox
```bash
# Access Netbox UI
open http://netbox.cloudigan.net

# Search for: sandbox-01, CT119, or 10.92.3.12
# Update name to: bni-toolkit-dev
```

---

**Status:** INCOMPLETE - Netbox update required
