# Infrastructure Change: QuantShift Bot Containers Renamed (CT100 & CT101)

**Date:** 2026-02-23  
**Type:** Infrastructure Change  
**Scope:** Homelab infrastructure, affects QuantShift bot application

---

## Summary

Renamed QuantShift bot containers CT100 and CT101 as part of container naming standardization project. Updated all infrastructure systems (Proxmox, DNS, Netbox) to reflect new names.

---

## Infrastructure Changes

### Container Renames

**CT100 (Primary Bot):**
- **Old Name:** quantshift-primary
- **New Name:** quantshift-bot-primary
- **IP Address:** 10.92.3.27 (unchanged)
- **Network:** vmbr0923 (unchanged)
- **Status:** Active and running

**CT101 (Standby Bot):**
- **Old Name:** quantshift-standby
- **New Name:** quantshift-bot-standby
- **IP Address:** 10.92.3.28 (unchanged)
- **Network:** vmbr0923 (unchanged)
- **Status:** Active and running

### DNS Records Updated

**CT100:**
- **Internal DNS:** quantshift-bot-primary.cloudigan.net → 10.92.3.27
- **Old DNS:** Did not exist (no cleanup needed)

**CT101:**
- **Internal DNS:** quantshift-bot-standby.cloudigan.net → 10.92.3.28
- **Old DNS:** Did not exist (no cleanup needed)

### Systems Updated
1. **Proxmox:** Container hostnames updated
2. **DC-01 DNS:** A records added (old records did not exist)
3. **NPM:** Not applicable (bots don't use proxy)
4. **AdGuard:** Verified no conflicting DNS rewrites
5. **Netbox IPAM:** VM names and IP DNS names updated

---

## Affected Applications

### QuantShift Trading Bot
- **Repository:** https://github.com/heybearc/quantshift
- **Primary Container:** CT100 (quantshift-bot-primary, 10.92.3.27)
- **Standby Container:** CT101 (quantshift-bot-standby, 10.92.3.28)
- **Status:** ✅ Both containers running
- **Public Access:** Via HAProxy (quantshift.io)

**Impact:** None - bots use IP addresses in configuration, not container hostnames.

---

## Control Plane Updates Needed

### 1. APP-MAP.md
**File:** `.cloudy-work/_cloudy-ops/context/APP-MAP.md`

**Current:**
```markdown
### QuantShift (Crypto Trading Bot)
- **Primary Bot:** quantshift-primary (Container 100, 10.92.3.27)
- **Standby Bot:** quantshift-standby (Container 101, 10.92.3.28)
```

**Update to:**
```markdown
### QuantShift (Crypto Trading Bot)
- **Primary Bot:** quantshift-bot-primary (Container 100, 10.92.3.27)
- **Standby Bot:** quantshift-bot-standby (Container 101, 10.92.3.28)
```

---

### 2. development-contract.md
**File:** `.cloudy-work/_cloudy-ops/policy/development-contract.md`

**Search for references to:**
- `quantshift-primary` → replace with `quantshift-bot-primary`
- `quantshift-standby` → replace with `quantshift-bot-standby`

---

### 3. DECISIONS.md
**File:** `.cloudy-work/_cloudy-ops/context/DECISIONS.md`

**Update any decisions referencing:**
- Container names for QuantShift bots
- Add note about rename on 2026-02-23

---

### 4. QuantShift Infrastructure Docs
**File:** `.cloudy-work/_cloudy-ops/docs/infrastructure/quantshift-*.md`

**Update all references:**
- `quantshift-primary` → `quantshift-bot-primary`
- `quantshift-standby` → `quantshift-bot-standby`
- `ssh quantshift-primary` → `ssh quantshift-bot-primary`
- `ssh quantshift-standby` → `ssh quantshift-bot-standby`

---

### 5. MCP Server Configuration
**File:** `shared/mcp-servers/homelab-blue-green-mcp/server.js`

**Update SSH hostnames:**
```javascript
'quantshift': {
  name: 'QuantShift',
  blueIp: '10.92.3.27',
  greenIp: '10.92.3.28',
  blueContainer: 100,
  greenContainer: 101,
  sshBlue: 'quantshift-bot-primary',    // Updated
  sshGreen: 'quantshift-bot-standby',   // Updated
  path: '/opt/quantshift',
  branch: 'main',
  pmBlue: 'quantshift-bot',
  pmGreen: 'quantshift-bot',
}
```

---

### 6. SSH Config
**File:** `~/.ssh/config.d/homelab.conf`

**Add aliases:**
```
Host quantshift-bot-primary
    HostName 10.92.3.27
    User root
    IdentityFile ~/.ssh/homelab_root

Host quantshift-bot-standby
    HostName 10.92.3.28
    User root
    IdentityFile ~/.ssh/homelab_root
```

---

## Testing Required

### QuantShift Repository
**Repository:** https://github.com/heybearc/quantshift

**Tests to run:**
1. **Bot connectivity test:**
   ```bash
   ssh quantshift-bot-primary
   cd /opt/quantshift
   pm2 list
   pm2 logs quantshift-bot --lines 20
   ```

2. **Database connectivity:**
   ```bash
   # Verify bot can connect to PostgreSQL at 10.92.3.21
   # Check logs for any connection issues
   ```

3. **HAProxy routing:**
   ```bash
   # Verify HAProxy routes to correct IPs
   curl http://quantshift.io:8001/health
   ```

4. **MCP deployment test:**
   ```bash
   # In quantshift repo
   mcp0_get_deployment_status(app: "quantshift")
   ```

**Expected Result:** All tests pass, no changes needed in bot code.

---

## Verification Completed

### All Systems Verified ✅

**CT100:**
- ✅ Proxmox: Container running with new hostname
- ✅ DC-01 DNS: New record resolving correctly
- ✅ NPM: Not applicable
- ✅ AdGuard: No conflicting rewrites
- ✅ Netbox: VM and IP records updated
- ✅ Application: Running successfully

**CT101:**
- ✅ Proxmox: Container running with new hostname
- ✅ DC-01 DNS: New record resolving correctly
- ✅ NPM: Not applicable
- ✅ AdGuard: No conflicting rewrites
- ✅ Netbox: VM and IP records updated
- ✅ Application: Running successfully

### No Application Changes Required ✅
- Bots use IP addresses in configuration
- HAProxy uses IP-based backends
- No hardcoded container hostname references found

---

## Documentation

**Homelab-Nexus Repository:**
- CT100 verification: `documentation/CT100-FINAL-VERIFICATION.md`
- CT101 verification: `documentation/CT101-FINAL-VERIFICATION.md`
- Container rename plan: `documentation/container-rename-plan.md`
- Verification process: `documentation/RENAME-VERIFICATION-PROCESS.md`

**Automation Scripts:**
- Verification script: `scripts/dns/verify-all-systems.sh`
- DNS update scripts: `scripts/dns/update-dc01-dns.sh`
- Master rename script: `scripts/dns/rename-container.sh`

---

## Next Steps

1. **Control Plane Team:** Update the 6 files/sections listed above
2. **QuantShift Team:** Run verification tests (should all pass)
3. **Update SSH Config:** Add quantshift-bot-primary and quantshift-bot-standby aliases
4. **Update MCP Server:** Update SSH hostnames in configuration

---

## Progress Update

**Completed Renames:** 3/8 containers
- ✅ CT119: sandbox-01 → bni-toolkit-dev
- ✅ CT101: quantshift-standby → quantshift-bot-standby
- ✅ CT100: quantshift-primary → quantshift-bot-primary

**Remaining:** 5 containers
- ⏳ CT132: green-theoshift → theoshift-green
- ⏳ CT134: blue-theoshift → theoshift-blue
- ⏳ CT121: npm → nginx-proxy
- ⏳ CT150: monitor → monitoring-stack
- ⏳ CT118: netbox-ipam → netbox

---

**Status:** Ready for control plane sync  
**Priority:** Medium (documentation update, no functional impact)  
**Breaking Change:** No (IPs and public domains unchanged)
