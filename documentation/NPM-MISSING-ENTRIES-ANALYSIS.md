# NPM Missing Entries Analysis

**Date:** 2026-02-23  
**Purpose:** Identify missing NPM proxy hosts from 2.5 month backup gap (Dec 1, 2025 - Feb 23, 2026)

---

## Data Sources Analyzed

### 1. Current NPM Proxy Hosts (59 entries)
From NPM database after December 1st restore

### 2. HAProxy Backends
From CT136 (haproxy @ 10.92.3.26)

### 3. Proxmox Container List (25 containers)
Active LXC containers on Proxmox host

### 4. Control Plane APP-MAP
Production applications and infrastructure services

---

## Analysis: NPM vs Other Sources

### Applications in APP-MAP but NOT in NPM

#### 1. QuantShift Web App (Blue-Green)
**From APP-MAP:**
- quantshift-blue (Container 137 @ 10.92.3.29)
- quantshift-green (Container 138 @ 10.92.3.30)
- Domains: quantshift.io, www.quantshift.io
- Direct access: blue.quantshift.io, green.quantshift.io
- Port: 3001

**NPM Status:** ❌ MISSING
- No entries for quantshift.io
- No entries for blue.quantshift.io or green.quantshift.io
- No entries for www.quantshift.io

**Action Required:** Add 4 proxy hosts:
1. `quantshift.io` → HAProxy VIP 10.92.3.33:80 (routes to live backend)
2. `www.quantshift.io` → HAProxy VIP 10.92.3.33:80
3. `blue.quantshift.io` → 10.92.3.29:3001 (direct access)
4. `green.quantshift.io` → 10.92.3.30:3001 (direct access)

#### 2. QuantShift Bot API
**From APP-MAP:**
- HAProxy bot backends: `trader_api` routes `quantshift.io:8001` → CT100 (primary), CT101 (backup)
- Bot API endpoints at port 8001

**NPM Status:** ❌ MISSING
- No entries for API subdomain (e.g., api.quantshift.io)

**Action Required:** Add proxy host:
- `api.quantshift.io` → HAProxy VIP 10.92.3.33:8001 (routes to bot API)

#### 3. Monitoring Stack (Grafana, Prometheus)
**From APP-MAP:**
- Grafana (port 3000) → `grafana.cloudigan.net`
- Prometheus (port 9090) → needs proxy host
- Alertmanager (port 9093) → needs proxy host
- Uptime Kuma (port 3001) → needs proxy host

**NPM Status:** ⚠️ PARTIAL
- ✅ grafana.cloudigan.net exists (ID not shown in current list - need to verify)
- ❌ prometheus.cloudigan.net missing
- ❌ alertmanager.cloudigan.net missing  
- ❌ uptime.cloudigan.net missing

**Action Required:** Verify grafana exists, add 3 proxy hosts:
1. `prometheus.cloudigan.net` → 10.92.3.2:9090
2. `alertmanager.cloudigan.net` → 10.92.3.2:9093
3. `uptime.cloudigan.net` → 10.92.3.2:3001

#### 4. BNI Chapter Toolkit
**From APP-MAP:**
- Container: bni-toolkit-dev (Container 119, 10.92.3.12)
- Port: 3001
- Repository: https://github.com/heybearc/bni-chapter-toolkit

**NPM Status:** ⚠️ PARTIAL
- ✅ bnitoolkit.cloudigan.net exists (ID 24 points to wrong port 3000, should be 3001)
- ❌ bni.cloudigan.net missing (shorter alias)

**Action Required:** 
1. Update existing entry: bnitoolkit.cloudigan.net port 3000 → 3001
2. Add alias: `bni.cloudigan.net` → 10.92.3.12:3001

#### 5. PostgreSQL Replica
**From APP-MAP:**
- Container: postgres-replica (CT151 @ 10.92.3.31)
- Hostname: postgres-replica.cloudigan.net

**NPM Status:** ❌ MISSING
- No entry for postgres-replica (not typically web-accessible, but may need for pgAdmin or monitoring)

**Action Required:** Consider adding if web access needed:
- `postgres-replica.cloudigan.net` → 10.92.3.31:5432 (or pgAdmin port if installed)

---

## Containers in Proxmox but NOT in NPM

### Web-Accessible Containers Missing from NPM

1. **qa-01 (CT115 @ 10.92.3.13)**
   - Purpose: E2E testing infrastructure
   - May have web UI for test results
   - **Action:** Verify if web UI exists, add if needed

2. **postgresql (CT131 @ 10.92.3.21)**
   - Primary database server
   - May have pgAdmin or monitoring UI
   - **Action:** Verify if web UI exists, add if needed

3. **quantshift-blue (CT137 @ 10.92.3.29)** ✅ Already identified above
4. **quantshift-green (CT138 @ 10.92.3.30)** ✅ Already identified above

---

## HAProxy Backends Analysis

### Backends that should have NPM entries

From HAProxy configuration, the following backends route traffic:

1. **theoshift_backend** → theoshift.com ✅ (exists in NPM)
2. **ldctools_backend** → ldctools.com ✅ (exists in NPM)
3. **quantshift_backend** → quantshift.io ❌ (MISSING from NPM)
4. **trader_api** → quantshift.io:8001 ❌ (MISSING from NPM)

---

## Summary of Missing NPM Entries

### Critical (Production Apps)

1. **quantshift.io** → 10.92.3.33:80 (HAProxy VIP)
2. **www.quantshift.io** → 10.92.3.33:80 (HAProxy VIP)
3. **blue.quantshift.io** → 10.92.3.29:3001 (direct)
4. **green.quantshift.io** → 10.92.3.30:3001 (direct)
5. **api.quantshift.io** → 10.92.3.33:8001 (HAProxy VIP for bot API)

### Important (Monitoring)

6. **prometheus.cloudigan.net** → 10.92.3.2:9090
7. **alertmanager.cloudigan.net** → 10.92.3.2:9093
8. **uptime.cloudigan.net** → 10.92.3.2:3001

### Nice to Have

9. **bni.cloudigan.net** → 10.92.3.12:3001 (alias for bnitoolkit)
10. **qa.cloudigan.net** → 10.92.3.13:? (if web UI exists)

### Needs Correction

11. **bnitoolkit.cloudigan.net** → Update port from 3000 to 3001

---

## Verification Needed

### Check if these domains exist in NPM (not visible in current list)

1. **grafana.cloudigan.net** - Should exist but not in sorted list output
2. **prometheus.cloudigan.net** - May exist but not visible

Let me query NPM for these specific domains:

```bash
ssh prox "sqlite3 /hdd-pool/subvol-121-disk-0/data/database.sqlite 'SELECT id, domain_names, forward_host, forward_port FROM proxy_host WHERE domain_names LIKE \"%grafana%\" OR domain_names LIKE \"%prometheus%\";'"
```

---

## Recommended Action Plan

### Phase 1: Critical Production Apps (QuantShift)
1. Add quantshift.io → 10.92.3.33:80
2. Add www.quantshift.io → 10.92.3.33:80
3. Add blue.quantshift.io → 10.92.3.29:3001
4. Add green.quantshift.io → 10.92.3.30:3001
5. Add api.quantshift.io → 10.92.3.33:8001

### Phase 2: Monitoring Infrastructure
6. Verify grafana.cloudigan.net exists
7. Add prometheus.cloudigan.net → 10.92.3.2:9090
8. Add alertmanager.cloudigan.net → 10.92.3.2:9093
9. Add uptime.cloudigan.net → 10.92.3.2:3001

### Phase 3: Corrections & Aliases
10. Update bnitoolkit.cloudigan.net port 3000 → 3001
11. Add bni.cloudigan.net → 10.92.3.12:3001

### Phase 4: Optional
12. Investigate qa-01 for web UI
13. Investigate postgresql for pgAdmin

---

## SSL Certificate Considerations

All new proxy hosts will need SSL certificates:
- quantshift.io domain (5 entries)
- cloudigan.net subdomains (monitoring + bni)

**Action:** Configure Let's Encrypt for all new domains after adding proxy hosts

---

**Status:** Analysis complete, ready for execution  
**Total Missing Entries:** 8-11 proxy hosts  
**Priority:** High (QuantShift production app not accessible via NPM)
