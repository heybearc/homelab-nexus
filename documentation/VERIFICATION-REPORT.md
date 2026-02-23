# Infrastructure Verification Report

**Date:** 2026-02-23  
**Purpose:** Cross-verify Proxmox (source of truth), DNS, NPM, and Netbox

---

## Source of Truth: Proxmox Container IPs

| CTID | Hostname | IP | Notes |
|------|----------|-----|-------|
| 100 | quantshift-bot-primary | 10.92.3.27 | ✅ Correct |
| 101 | quantshift-bot-standby | 10.92.3.28 | ✅ Correct |
| 113 | adguard | 10.92.3.11 | ✅ Correct |
| 115 | qa-01 | 10.92.3.13 | ✅ Correct |
| 118 | netbox | 10.92.3.18 | ✅ Correct |
| 119 | bni-toolkit-dev | 10.92.3.12 | ✅ Correct |
| 120 | readarr | 10.92.3.4 | ✅ Correct |
| 121 | nginx-proxy | 10.92.3.3 | ✅ Correct |
| 123 | prowlarr | 10.92.3.6 | ✅ Correct |
| 124 | radarr | 10.92.3.7 | ✅ Correct |
| 125 | sonarr | 10.92.3.8 | ✅ Correct |
| 127 | sabnzbd | 10.92.3.16 | ✅ Correct |
| 128 | plex | 10.92.3.17 | ✅ Correct |
| 129 | calibre-web | 10.92.3.19 | ✅ Correct |
| 131 | postgresql | 10.92.3.21 | ✅ Correct |
| 132 | theoshift-green | 10.92.3.22 | ✅ Correct |
| 133 | ldctools-blue | 10.92.3.23 | ✅ Correct |
| 134 | theoshift-blue | 10.92.3.24 | ✅ Correct |
| 135 | ldctools-green | 10.92.3.25 | ✅ Correct |
| 136 | haproxy | 10.92.3.26 | ✅ Correct (+ VIP 10.92.3.33) |
| 137 | quantshift-blue | 10.92.3.29 | ✅ Correct |
| 138 | quantshift-green | 10.92.3.30 | ✅ Correct |
| 139 | haproxy-standby | 10.92.3.32 | ✅ Correct |
| 150 | monitoring-stack | 10.92.3.2 | ✅ Correct |
| 151 | postgres-replica | 10.92.3.31 | ✅ Correct |

---

## DNS Verification (Should point to NPM 10.92.3.3 for web apps)

### ✅ Correct DNS Entries (pointing to NPM 10.92.3.3)
- adguard.cloudigan.net → 10.92.3.3 ✅
- bnitoolkit.cloudigan.net → 10.92.3.3 ✅
- books.cloudigan.net → 10.92.3.3 ✅
- grafana.cloudigan.net → 10.92.3.3 ✅
- haproxy.cloudigan.net → 10.92.3.3 ✅
- ldc.cloudigan.net → 10.92.3.3 ✅
- ldctools.cloudigan.net → 10.92.3.3 ✅
- blue.ldctools.cloudigan.net → 10.92.3.3 ✅
- green.ldctools.cloudigan.net → 10.92.3.3 ✅
- netbox.cloudigan.net → 10.92.3.3 ✅ (also has 10.92.3.18 direct)
- nextcloud.cloudigan.net → 10.92.3.3 ✅
- npm.cloudigan.net → 10.92.3.3 ✅
- nginx-proxy.cloudigan.net → 10.92.3.3 ✅
- plex.cloudigan.net → 10.92.3.3 ✅
- prometheus.cloudigan.net → 10.92.3.3 ✅
- prowlarr.cloudigan.net → 10.92.3.3 ✅
- radarr.cloudigan.net → 10.92.3.3 ✅
- readarr.cloudigan.net → 10.92.3.3 ✅
- sabnzbd.cloudigan.net → 10.92.3.3 ✅
- sonarr.cloudigan.net → 10.92.3.3 ✅
- trader.cloudigan.net → 10.92.3.3 ✅
- api.trader.cloudigan.net → 10.92.3.3 ✅
- primary.trader.cloudigan.net → 10.92.3.3 ✅
- standby.trader.cloudigan.net → 10.92.3.3 ✅
- truenas.cloudigan.net → 10.92.3.3 ✅
- vaultwarden.cloudigan.net → 10.92.3.3 ✅

### ✅ Correct DNS Entries (direct to containers)
- bni-toolkit-dev.cloudigan.net → 10.92.3.12 ✅ (direct)
- blue-theoshift.cloudigan.net → 10.92.3.24 ✅ (direct)
- green-theoshift.cloudigan.net → 10.92.3.22 ✅ (direct)
- theoshift-blue.cloudigan.net → 10.92.3.24 ✅ (direct)
- theoshift-green.cloudigan.net → 10.92.3.22 ✅ (direct)
- haproxy-standby.cloudigan.net → 10.92.3.32 ✅ (direct)
- haproxy-vip.cloudigan.net → 10.92.3.33 ✅ (VIP)
- monitoring-stack.cloudigan.net → 10.92.3.2 ✅ (direct)
- postgres-replica.cloudigan.net → 10.92.3.31 ✅ (direct)
- qa-01.cloudigan.net → 10.92.3.13 ✅ (direct)
- quantshift-bot-primary.cloudigan.net → 10.92.3.27 ✅ (direct)
- quantshift-bot-standby.cloudigan.net → 10.92.3.28 ✅ (direct)

---

## NPM Proxy Host Verification

### ✅ Correct NPM Entries
- ID 24: adguard.cloudigan.net → 10.92.3.11:3000 ✅
- ID 40: netbox.cloudigan.net → 10.92.3.18:80 ✅
- ID 50: ldctools.cloudigan.net → 10.92.3.26:80 ✅ (HAProxy)
- ID 53: haproxy.cloudigan.net → 10.92.3.26:8404 ✅
- ID 54: green.ldctools.cloudigan.net → 10.92.3.25:3001 ✅
- ID 55: blue.ldctools.cloudigan.net → 10.92.3.23:3001 ✅
- ID 56: blue.theoshift.com → 10.92.3.24:3001 ✅
- ID 57: green.theoshift.com → 10.92.3.22:3001 ✅
- ID 58: theoshift.com → 10.92.3.26:80 ✅ (HAProxy)
- ID 59: blue.ldctools.com → 10.92.3.23:3001 ✅
- ID 60: green.ldctools.com → 10.92.3.25:3001 ✅
- ID 61: ldctools.com → 10.92.3.26:80 ✅ (HAProxy)

### ❌ MISSING NPM Entries (from 2.5 month gap)

**QuantShift (CRITICAL - Production app not accessible):**
- quantshift.io → Should point to HAProxy VIP 10.92.3.33:80
- www.quantshift.io → Should point to HAProxy VIP 10.92.3.33:80
- blue.quantshift.io → Should point to 10.92.3.29:3001 (direct)
- green.quantshift.io → Should point to 10.92.3.30:3001 (direct)
- api.quantshift.io → Should point to HAProxy VIP 10.92.3.33:8001 (bot API)

**BNI Toolkit:**
- No NPM entry found for bnitoolkit.cloudigan.net
- DNS points to 10.92.3.3 (NPM) but NPM has no proxy host configured
- **Action:** Add NPM entry: bnitoolkit.cloudigan.net → 10.92.3.12:3001

**Monitoring (Grafana exists, others missing):**
- grafana.cloudigan.net → Likely exists but not in filtered output
- prometheus.cloudigan.net → DNS points to 10.92.3.3, need NPM entry → 10.92.3.2:9090
- alertmanager.cloudigan.net → Need NPM entry → 10.92.3.2:9093
- uptime.cloudigan.net → Need NPM entry → 10.92.3.2:3001

---

## Netbox Verification

### ❌ INCORRECT Netbox Entries

**Netbox has stale/incorrect data:**
- monitoring-stack: Shows 10.92.3.3 (WRONG) - Should be 10.92.3.2
- nginx-proxy: Shows 10.92.3.12 (WRONG) - Should be 10.92.3.3
- netbox: Shows 10.92.3.6 (WRONG) - Should be 10.92.3.18
- theoshift-blue: Shows 10.92.3.23 (WRONG) - Should be 10.92.3.24
- theoshift-green: Shows 10.92.3.4 (WRONG) - Should be 10.92.3.22
- bni-toolkit-dev: Shows N/A (MISSING)
- ldctools-blue: Shows N/A (MISSING)

**Netbox needs major corrections to match Proxmox reality.**

---

## Summary of Issues

### CRITICAL
1. **QuantShift production app completely missing from NPM** (5 proxy hosts needed)
2. **BNI Toolkit missing from NPM** (DNS points to NPM but no proxy host exists)

### HIGH
3. **Netbox has incorrect IPs for multiple containers** (needs bulk update)
4. **Monitoring infrastructure partially missing from NPM** (prometheus, alertmanager, uptime)

### Verification Status
- ✅ **Proxmox:** Source of truth, all IPs verified
- ✅ **DNS:** Correctly points web apps to NPM (10.92.3.3)
- ⚠️ **NPM:** Missing 9-10 proxy hosts from backup gap
- ❌ **Netbox:** Has incorrect/stale data, needs corrections

---

## Recommended Actions

### Priority 1: Fix NPM (restore missing proxy hosts)
1. Add QuantShift proxy hosts (5 entries)
2. Add BNI Toolkit proxy host (1 entry)
3. Add monitoring proxy hosts (3-4 entries)

### Priority 2: Fix Netbox (update to match Proxmox)
1. Update monitoring-stack IP: 10.92.3.3 → 10.92.3.2
2. Update nginx-proxy IP: 10.92.3.12 → 10.92.3.3
3. Update netbox IP: 10.92.3.6 → 10.92.3.18
4. Update theoshift-blue IP: 10.92.3.23 → 10.92.3.24
5. Update theoshift-green IP: 10.92.3.4 → 10.92.3.22
6. Add bni-toolkit-dev: 10.92.3.12
7. Add ldctools-blue: 10.92.3.23

---

**Conclusion:** Your suspicion was correct. BNI Toolkit DNS points to NPM (10.92.3.3) but NPM has no proxy host configured for it, so it's broken. Additionally, QuantShift production app is completely missing from NPM.
