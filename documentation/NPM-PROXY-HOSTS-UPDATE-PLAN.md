# NPM Proxy Hosts Update Plan

**Date:** 2026-02-23  
**Purpose:** Update NPM proxy host configurations to reflect renamed containers

---

## Renamed Containers Requiring NPM Updates

### Container Renames Completed

| Old Name | New Name | IP | CTID | NPM Impact |
|----------|----------|-----|------|------------|
| sandbox-01 | bni-toolkit-dev | 10.92.3.12 | 119 | No proxy hosts found |
| quantshift-standby | quantshift-bot-standby | 10.92.3.28 | 101 | No proxy hosts (bot) |
| quantshift-primary | quantshift-bot-primary | 10.92.3.27 | 100 | No proxy hosts (bot) |
| green-theoshift | theoshift-green | 10.92.3.22 | 132 | **2 proxy hosts** |
| blue-theoshift | theoshift-blue | 10.92.3.24 | 134 | **2 proxy hosts** |
| monitor | monitoring-stack | 10.92.3.2 | 150 | No proxy hosts found |
| netbox-ipam | netbox | 10.92.3.18 | 118 | **1 proxy host** |
| npm | nginx-proxy | 10.92.3.3 | 121 | **2 proxy hosts** |

---

## NPM Proxy Hosts Requiring Updates

### 1. NPM Self-Reference (ID: 1, 2)
**Current:**
- ID 1: `npm.cloudigan.net` → 10.92.3.1:81
- ID 2: `npm.cloudigan.net` → 10.92.3.3:81

**Action:** These reference the NPM admin UI itself
- ID 1 points to wrong IP (10.92.3.1 should be 10.92.3.3)
- ID 2 is correct IP but domain may need updating
- **Decision:** Update domain to `nginx-proxy.cloudigan.net` or keep as `npm.cloudigan.net`?

### 2. TheoShift Green (ID: 49, 52, 57)
**Current:**
- ID 49: `green.attendant.cloudigan.net` → 10.92.3.24:3001
- ID 52: `blue.attendant.cloudigan.net` → 10.92.3.22:3001
- ID 57: `green.theoshift.com` → 10.92.3.24:3001

**Issue:** IPs are swapped!
- green.attendant points to 10.92.3.24 (should be 10.92.3.22 - theoshift-green)
- blue.attendant points to 10.92.3.22 (should be 10.92.3.24 - theoshift-blue)

**Action Required:**
- Swap IPs for green/blue attendant domains
- Verify theoshift.com domains are correct

### 3. TheoShift Blue (ID: 56)
**Current:**
- ID 56: `blue.theoshift.com` → 10.92.3.22:3001

**Issue:** IP is swapped!
- Should point to 10.92.3.24 (theoshift-blue)

**Action Required:**
- Update IP from 10.92.3.22 to 10.92.3.24

### 4. LDC Tools (ID: 54, 55, 59, 60)
**Current:**
- ID 54: `green.ldctools.cloudigan.net` → 10.92.3.25:3001
- ID 55: `blue.ldctools.cloudigan.net` → 10.92.3.23:3001
- ID 59: `blue.ldctools.com` → 10.92.3.23:3001
- ID 60: `green.ldctools.com` → 10.92.3.25:3001

**Status:** These appear correct (no rename for LDC containers)
- No action needed

### 5. Netbox (ID: 40)
**Current:**
- ID 40: `netbox.cloudigan.net` → 10.92.3.18:80

**Status:** IP-based, correct
- No action needed (IP unchanged)

---

## Critical Issues Found

### Issue 1: TheoShift Green/Blue IPs Swapped

**Current State:**
```
green.attendant.cloudigan.net → 10.92.3.24 (WRONG - this is blue)
blue.attendant.cloudigan.net → 10.92.3.22 (WRONG - this is green)
blue.theoshift.com → 10.92.3.22 (WRONG - should be 10.92.3.24)
green.theoshift.com → 10.92.3.24 (WRONG - should be 10.92.3.22)
```

**Correct State Should Be:**
```
CT132 (theoshift-green): 10.92.3.22
CT134 (theoshift-blue): 10.92.3.24

green.attendant.cloudigan.net → 10.92.3.22
blue.attendant.cloudigan.net → 10.92.3.24
green.theoshift.com → 10.92.3.22
blue.theoshift.com → 10.92.3.24
```

**Impact:** HIGH - Users accessing green/blue environments are hitting the wrong servers!

---

## Update Actions Required

### Priority 1: Fix TheoShift Green/Blue IP Swap (CRITICAL)

**Proxy Host ID 49:** `green.attendant.cloudigan.net`
- Current: 10.92.3.24:3001
- Update to: 10.92.3.22:3001

**Proxy Host ID 52:** `blue.attendant.cloudigan.net`
- Current: 10.92.3.22:3001
- Update to: 10.92.3.24:3001

**Proxy Host ID 56:** `blue.theoshift.com`
- Current: 10.92.3.22:3001
- Update to: 10.92.3.24:3001

**Proxy Host ID 57:** `green.theoshift.com`
- Current: 10.92.3.24:3001
- Update to: 10.92.3.22:3001

### Priority 2: Fix NPM Self-Reference

**Proxy Host ID 1:** `npm.cloudigan.net`
- Current: 10.92.3.1:81 (WRONG IP)
- Update to: 10.92.3.3:81
- Consider: Rename domain to `nginx-proxy.cloudigan.net`?

**Proxy Host ID 2:** `npm.cloudigan.net` (duplicate)
- Current: 10.92.3.3:81 (CORRECT)
- Consider: Delete duplicate or rename to `nginx-proxy.cloudigan.net`

---

## SQL Update Commands

### Fix TheoShift Green/Blue IPs

```sql
-- Fix green.attendant (ID 49): 10.92.3.24 → 10.92.3.22
UPDATE proxy_host SET forward_host = '10.92.3.22' WHERE id = 49;

-- Fix blue.attendant (ID 52): 10.92.3.22 → 10.92.3.24
UPDATE proxy_host SET forward_host = '10.92.3.24' WHERE id = 52;

-- Fix blue.theoshift.com (ID 56): 10.92.3.22 → 10.92.3.24
UPDATE proxy_host SET forward_host = '10.92.3.24' WHERE id = 56;

-- Fix green.theoshift.com (ID 57): 10.92.3.24 → 10.92.3.22
UPDATE proxy_host SET forward_host = '10.92.3.22' WHERE id = 57;
```

### Fix NPM Self-Reference

```sql
-- Fix npm.cloudigan.net (ID 1): wrong IP
UPDATE proxy_host SET forward_host = '10.92.3.3' WHERE id = 1;

-- Optional: Update domain names to nginx-proxy.cloudigan.net
UPDATE proxy_host SET domain_names = '["nginx-proxy.cloudigan.net"]' WHERE id = 1;
UPDATE proxy_host SET domain_names = '["nginx-proxy.cloudigan.net"]' WHERE id = 2;
```

---

## Verification Steps

After updates:

1. **Restart NPM service** to reload configuration
2. **Test green environment:** `curl -I https://green.attendant.cloudigan.net`
3. **Test blue environment:** `curl -I https://blue.attendant.cloudigan.net`
4. **Test theoshift.com domains:** `curl -I https://green.theoshift.com`
5. **Test NPM admin UI:** `curl -I http://nginx-proxy.cloudigan.net:81`
6. **Verify HAProxy VIP** still routes correctly to blue/green

---

## Execution Plan

1. ✅ Create ZFS snapshot of NPM container (already done: `pre-rename-20260223-153305`)
2. ⏳ Execute SQL updates to fix TheoShift green/blue IPs
3. ⏳ Execute SQL updates to fix NPM self-reference
4. ⏳ Restart NPM service
5. ⏳ Verify all proxy hosts working
6. ⏳ Test TheoShift blue-green switching
7. ⏳ Document changes

---

## Rollback Plan

If issues occur:

```bash
# Rollback to snapshot
ssh prox "pct stop 121"
ssh prox "zfs rollback hdd-pool/subvol-121-disk-0@pre-rename-20260223-153305"
ssh prox "pct start 121"
```

---

**Status:** Ready for execution  
**Risk:** Medium (critical production services affected)  
**Estimated Time:** 5 minutes
