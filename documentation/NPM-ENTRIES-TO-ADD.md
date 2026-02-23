# NPM Proxy Hosts to Add

**Date:** 2026-02-23  
**Purpose:** Missing proxy hosts from 2.5 month backup gap (Dec 1, 2025 - Feb 23, 2026)

---

## Critical Missing Entries (QuantShift Production)

### 1. QuantShift Main Domain
**Domain:** `quantshift.io`  
**Forward to:** 10.92.3.33:80 (HAProxy VIP)  
**Backend:** quantshift-green-backend (currently LIVE per HAProxy config)  
**SSL:** Required (Let's Encrypt)  
**Priority:** CRITICAL

### 2. QuantShift WWW Alias
**Domain:** `www.quantshift.io`  
**Forward to:** 10.92.3.33:80 (HAProxy VIP)  
**Backend:** Same as quantshift.io  
**SSL:** Required (Let's Encrypt)  
**Priority:** CRITICAL

### 3. QuantShift Blue Direct Access
**Domain:** `blue.quantshift.io`  
**Forward to:** 10.92.3.29:3001 (direct to CT137)  
**Purpose:** Direct access to blue environment for testing  
**SSL:** Required (Let's Encrypt)  
**Priority:** HIGH

### 4. QuantShift Green Direct Access
**Domain:** `green.quantshift.io`  
**Forward to:** 10.92.3.30:3001 (direct to CT138)  
**Purpose:** Direct access to green environment for testing  
**SSL:** Required (Let's Encrypt)  
**Priority:** HIGH

### 5. QuantShift Bot API
**Domain:** `api.quantshift.io`  
**Forward to:** 10.92.3.33:8001 (HAProxy VIP)  
**Backend:** trader_api (routes to CT100 primary, CT101 backup)  
**SSL:** Required (Let's Encrypt)  
**Priority:** HIGH  
**Note:** Bot API for external integrations

---

## Monitoring Infrastructure

### 6. Grafana
**Domain:** `grafana.cloudigan.net`  
**Forward to:** 10.92.3.2:3000 (CT150 monitoring-stack)  
**SSL:** Required (Let's Encrypt)  
**Priority:** HIGH  
**Status:** ⚠️ Verify if exists - not found in current NPM list

### 7. Prometheus
**Domain:** `prometheus.cloudigan.net`  
**Forward to:** 10.92.3.2:9090 (CT150 monitoring-stack)  
**SSL:** Required (Let's Encrypt)  
**Priority:** MEDIUM  
**Status:** ❌ Missing

### 8. Alertmanager
**Domain:** `alertmanager.cloudigan.net`  
**Forward to:** 10.92.3.2:9093 (CT150 monitoring-stack)  
**SSL:** Required (Let's Encrypt)  
**Priority:** MEDIUM  
**Status:** ❌ Missing

### 9. Uptime Kuma
**Domain:** `uptime.cloudigan.net`  
**Forward to:** 10.92.3.2:3001 (CT150 monitoring-stack)  
**SSL:** Required (Let's Encrypt)  
**Priority:** MEDIUM  
**Status:** ❌ Missing

---

## Development & Aliases

### 10. BNI Toolkit Short Alias
**Domain:** `bni.cloudigan.net`  
**Forward to:** 10.92.3.12:3001 (CT119 bni-toolkit-dev)  
**SSL:** Required (Let's Encrypt)  
**Priority:** LOW  
**Note:** Shorter alias for bnitoolkit.cloudigan.net

---

## Corrections Needed

### Fix: BNI Toolkit Port
**Current:** bnitoolkit.cloudigan.net → 10.92.3.11:3000  
**Should be:** bnitoolkit.cloudigan.net → 10.92.3.12:3001  
**Issue:** Wrong IP (3.11 is AdGuard) and wrong port (3000 vs 3001)  
**Priority:** HIGH

---

## HAProxy Configuration Reference

From HAProxy on CT136:

**QuantShift ACLs:**
```
acl is_quantshift hdr(host) -i quantshift.io
acl is_quantshift_blue hdr(host) -i blue.quantshift.io
acl is_quantshift_green hdr(host) -i green.quantshift.io
```

**Current LIVE Backend:** quantshift-green-backend (CT138 @ 10.92.3.30:3001)

**Backends:**
- `quantshift-blue-backend` → 10.92.3.29:3001 (CT137)
- `quantshift-green-backend` → 10.92.3.30:3001 (CT138)
- `trader_backend` → 10.92.3.29:3001 (dashboard - blue only?)
- `trader_api` → 10.92.3.27:8001 (primary), 10.92.3.28:8001 (backup)

---

## Summary

**Total to Add:** 9-10 new proxy hosts  
**Total to Fix:** 1 existing proxy host  

**By Priority:**
- **CRITICAL (2):** quantshift.io, www.quantshift.io
- **HIGH (4):** blue.quantshift.io, green.quantshift.io, api.quantshift.io, bnitoolkit fix, grafana verify
- **MEDIUM (4):** prometheus, alertmanager, uptime
- **LOW (1):** bni alias

---

## Next Steps

1. **Verify grafana.cloudigan.net** - Check if it exists in NPM
2. **Add QuantShift domains** - Critical for production access
3. **Add monitoring domains** - Important for ops visibility
4. **Fix bnitoolkit** - Wrong IP and port
5. **Configure SSL certificates** - Let's Encrypt for all new domains
6. **Test all new proxy hosts** - Verify routing works correctly

---

**Ready for execution?**
