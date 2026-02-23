# Infrastructure Change: Container Rename CT119

**Date:** 2026-02-23  
**Type:** Infrastructure Change  
**Scope:** Homelab infrastructure, affects BNI Chapter Toolkit app

---

## Summary

Renamed container CT119 from `sandbox-01` to `bni-toolkit-dev` as part of container naming standardization project. Updated all infrastructure systems (Proxmox, DNS, NPM, Netbox) to reflect new name.

---

## Infrastructure Changes

### Container Rename
- **CTID:** 119
- **Old Name:** sandbox-01
- **New Name:** bni-toolkit-dev
- **IP Address:** 10.92.3.12 (unchanged)
- **Network:** vmbr0923 (unchanged)
- **Status:** Active and running

### DNS Records Updated
- **Internal DNS:** bni-toolkit-dev.cloudigan.net → 10.92.3.12
- **Public DNS:** bnitoolkit.cloudigan.net → 10.92.3.3 (NPM, unchanged)
- **Old DNS Removed:** sandbox-01.cloudigan.net (no longer resolves)

### Systems Updated
1. **Proxmox:** Container hostname updated
2. **DC-01 DNS:** A records updated (old removed, new added)
3. **NPM:** Verified proxy host configuration (no changes needed)
4. **AdGuard:** Verified no conflicting DNS rewrites
5. **Netbox IPAM:** VM name and IP DNS name updated

---

## Affected Applications

### BNI Chapter Toolkit
- **Repository:** https://github.com/heybearc/bni-chapter-toolkit
- **Container:** CT119 (bni-toolkit-dev)
- **IP:** 10.92.3.12
- **Port:** 3001
- **Public URL:** https://bnitoolkit.cloudigan.net (unchanged)
- **Status:** ✅ Running and accessible

**Impact:** None - application uses IP addresses and domain names in configuration, not container hostnames.

---

## Control Plane Updates Needed

### 1. APP-MAP.md
**File:** `.cloudy-work/_cloudy-ops/context/APP-MAP.md`

**Current:**
```markdown
### BNI Chapter Toolkit (Development)
- **Type:** Digital platform for BNI chapters (B2B SaaS)
- **Container:** sandbox-01 (Container 119, 10.92.3.12)
- **Canonical path:** /opt/bni-chapter-toolkit
- **Port:** 3001
- **Database:** bni_toolkit on shared PostgreSQL (10.92.3.21)
```

**Update to:**
```markdown
### BNI Chapter Toolkit (Development)
- **Type:** Digital platform for BNI chapters (B2B SaaS)
- **Container:** bni-toolkit-dev (Container 119, 10.92.3.12)
- **Canonical path:** /opt/bni-chapter-toolkit
- **Port:** 3001
- **Database:** bni_toolkit on shared PostgreSQL (10.92.3.21)
```

---

### 2. development-contract.md
**File:** `.cloudy-work/_cloudy-ops/policy/development-contract.md`

**Current:**
```markdown
| **BNI Toolkit** | `/opt/bni-toolkit` | N/A | sandbox-01 |
```

**Update to:**
```markdown
| **BNI Toolkit** | `/opt/bni-toolkit` | N/A | bni-toolkit-dev |
```

---

### 3. DECISIONS.md
**File:** `.cloudy-work/_cloudy-ops/context/DECISIONS.md`

**Current:**
```markdown
## D-LOCAL-009: Sandbox-01 as reusable development container
- **Decision:** Container 119 (sandbox-01, 10.92.2.6) serves as reusable sandbox...
- **Pattern:** IdeaForge idea → GitHub repo → sandbox-01 deployment → iterate...
```

**Update to:**
```markdown
## D-LOCAL-009: Development container for sandbox apps
- **Decision:** Container 119 (bni-toolkit-dev, 10.92.3.12) serves as development container for sandbox apps before blue-green promotion.
- **Pattern:** IdeaForge idea → GitHub repo → bni-toolkit-dev deployment → iterate → promote to blue-green when production-ready.
- **Note:** Renamed from sandbox-01 to bni-toolkit-dev on 2026-02-23 for clarity.
```

---

### 4. D-024-IMPLEMENTATION-BNI-TOOLKIT.md
**File:** `.cloudy-work/_cloudy-ops/policy/D-024-IMPLEMENTATION-BNI-TOOLKIT.md`

**Update all references:**
- Replace `sandbox-01` with `bni-toolkit-dev`
- Replace `ssh sandbox-01` with `ssh bni-toolkit-dev`
- Update any deployment commands

---

### 5. sandbox-app-support.md
**File:** `.cloudy-work/_cloudy-ops/docs/infrastructure/sandbox-app-support.md`

**Current:**
```markdown
The sandbox-01 container (LXC 119, 10.92.3.12) is a reusable development environment...
```

**Update to:**
```markdown
The bni-toolkit-dev container (LXC 119, 10.92.3.12) is a development environment for sandbox apps...
```

---

### 6. SSH Config
**File:** `~/.ssh/config.d/homelab.conf`

**Add alias:**
```
Host bni-toolkit-dev
    HostName 10.92.3.12
    User root
    IdentityFile ~/.ssh/homelab_root
```

---

## Testing Required

### BNI Chapter Toolkit Repository
**Repository:** https://github.com/heybearc/bni-chapter-toolkit

**Tests to run:**
1. **Deployment test:**
   ```bash
   ssh bni-toolkit-dev
   cd /opt/bni-chapter-toolkit
   git pull
   npm install
   pm2 restart bni-toolkit
   ```

2. **Application health check:**
   ```bash
   curl http://10.92.3.12:3001
   curl https://bnitoolkit.cloudigan.net
   ```

3. **Database connectivity:**
   ```bash
   # Verify app can connect to PostgreSQL at 10.92.3.21
   # Check logs: pm2 logs bni-toolkit
   ```

4. **E2E tests (if configured):**
   ```bash
   ssh qa-01
   cd /opt/tests/bni-chapter-toolkit
   npm run test:e2e
   ```

**Expected Result:** All tests pass, no changes needed in app code.

---

## Verification Completed

### All Systems Verified ✅
- ✅ Proxmox: Container running with new hostname
- ✅ DC-01 DNS: New record resolving correctly
- ✅ NPM: Proxy host working (bnitoolkit.cloudigan.net)
- ✅ AdGuard: No conflicting rewrites
- ✅ Netbox: VM and IP records updated
- ✅ Application: Running and accessible

### No Application Changes Required ✅
- Application uses IP addresses in .env (10.92.3.21 for database)
- Application uses domain name for public access (bnitoolkit.cloudigan.net)
- No hardcoded container hostname references found

---

## Documentation

**Homelab-Nexus Repository:**
- Container rename plan: `documentation/container-rename-plan.md`
- Verification process: `documentation/RENAME-VERIFICATION-PROCESS.md`
- CT119 final report: `documentation/CT119-FINAL-VERIFICATION.md`

**Automation Scripts:**
- Verification script: `scripts/dns/verify-all-systems.sh`
- DNS update scripts: `scripts/dns/update-dc01-dns.sh`, `scripts/dns/update-adguard-dns.sh`
- Master rename script: `scripts/dns/rename-container.sh`

---

## Next Steps

1. **Control Plane Team:** Update the 6 files listed above
2. **BNI Toolkit Team:** Run verification tests (should all pass)
3. **Update SSH Config:** Add bni-toolkit-dev alias
4. **Continue Renames:** Proceed with CT101 and CT100 using same process

---

**Status:** Ready for control plane sync  
**Priority:** Medium (documentation update, no functional impact)  
**Breaking Change:** No (IP and public domain unchanged)
