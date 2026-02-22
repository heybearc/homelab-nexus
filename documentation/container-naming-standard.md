# Container Naming & ID Standard

**Created:** 2026-02-22  
**Status:** Active - Apply to all new and renamed containers  
**Scope:** Proxmox LXC containers and VMs

---

## Container Naming Convention

### Format
```
{function}-{role}[-{instance}]
```

### Rules

1. **All lowercase** - No capital letters
2. **Hyphen-separated** - Use hyphens, not underscores or spaces
3. **Function first** - What the service does (e.g., `nginx-proxy`, `postgres`)
4. **Role second** - Deployment role (e.g., `blue`, `green`, `primary`, `standby`)
5. **Instance number** - Only if multiple identical services (e.g., `-01`, `-02`)
6. **Keep it short** - Aim for 2-3 words maximum
7. **Be descriptive** - Name should indicate purpose without documentation

### Examples

**Good:**
- `nginx-proxy` - Clear function
- `postgres-primary` - Function + role
- `theoshift-blue` - App + deployment role
- `monitoring-stack` - Descriptive function
- `bni-toolkit-dev` - App + environment

**Bad:**
- `npm` - Unclear abbreviation
- `blue-theoshift` - Role before function (inconsistent)
- `sandbox-01` - Generic, unclear purpose
- `monitor` - Too generic
- `server1` - No context

---

## Container/VM ID (CTID/VMID) Numbering Standard

### ID Ranges by Function

**100-109: Bot & Automation Containers**
- 100: quantshift-bot-primary
- 101: quantshift-bot-standby
- 102-109: Reserved for future bots/automation

**110-119: Development & Testing**
- 115: qa-testing (centralized E2E testing)
- 119: bni-toolkit-dev (sandbox development)
- 110-114, 116-118: Reserved for future dev/test

**120-129: Media Management Stack**
- 120: readarr
- 123: prowlarr
- 124: radarr
- 125: sonarr
- 126: transmission
- 127: sabnzbd
- 128: plex
- 129: calibre-web
- 121-122: Reserved for future media services

**130-139: Core Infrastructure**
- 131: postgres-primary
- 132: theoshift-green
- 133: ldctools-blue
- 134: theoshift-blue
- 135: ldctools-green
- 136: haproxy
- 137: quantshift-blue
- 138: quantshift-green
- 139: haproxy-standby
- 130: Reserved

**140-149: Network & Proxy Services**
- 113: adguard (legacy ID, should be 140-149)
- 118: netbox (legacy ID, should be 140-149)
- 121: nginx-proxy (legacy ID, should be 140-149)
- 140-149: Reserved for network services

**150-159: Monitoring & Observability**
- 150: monitoring-stack
- 151: postgres-replica
- 152-159: Reserved for monitoring/logging

**160-169: Storage & Backup**
- Reserved for future storage services

**170-179: Security & Access**
- Reserved for future security services

**180-189: Utility Services**
- Reserved for future utility services

**190-199: Reserved**
- Future expansion

---

## Current State vs Standard

### Containers Needing Rename

| Current CTID | Current Name | Proposed Name | Priority | Reason |
|--------------|--------------|---------------|----------|--------|
| 132 | green-theoshift | theoshift-green | High | Consistency (role after app) |
| 134 | blue-theoshift | theoshift-blue | High | Consistency (role after app) |
| 121 | npm | nginx-proxy | High | Clarity (no abbreviations) |
| 119 | sandbox-01 | bni-toolkit-dev | High | Clarity (purpose unclear) |
| 150 | monitor | monitoring-stack | Medium | Descriptive |
| 118 | netbox-ipam | netbox | Medium | Simplification (IPAM implied) |
| 100 | quantshift-primary | quantshift-bot-primary | Medium | Clarity (distinguish from web) |
| 101 | quantshift-standby | quantshift-bot-standby | Medium | Clarity (distinguish from web) |

### Containers Already Compliant

- `adguard` (113) ✅
- `readarr` (120) ✅
- `prowlarr` (123) ✅
- `radarr` (124) ✅
- `sonarr` (125) ✅
- `sabnzbd` (127) ✅
- `plex` (128) ✅
- `calibre-web` (129) ✅
- `postgresql` (131) - Could be `postgres-primary` for clarity
- `ldctools-blue` (133) ✅
- `ldctools-green` (135) ✅
- `haproxy` (136) ✅
- `quantshift-blue` (137) ✅
- `quantshift-green` (138) ✅
- `haproxy-standby` (139) ✅
- `postgres-replica` (151) ✅
- `qa-01` (115) - Could be `qa-testing` for clarity

---

## Container ID Reassignment Strategy

### Current Misalignments

**Network services in wrong range:**
- 113 (adguard) → Should be 140-149
- 118 (netbox) → Should be 140-149
- 121 (nginx-proxy) → Should be 140-149

**Options:**

**Option A: Leave Legacy IDs (Recommended)**
- Keep existing IDs to avoid disruption
- Apply standard to NEW containers only
- Document exceptions in this file

**Option B: Gradual Migration**
- Reassign IDs during major service upgrades
- Create new container with correct ID
- Migrate data, test, destroy old

**Option C: Full Reassignment**
- Plan maintenance window
- Reassign all containers to correct ranges
- High risk, high disruption

**Recommendation:** Option A - Leave legacy IDs, apply standard to new containers.

---

## Rename Procedure

### Pre-Rename Checklist

1. **Identify dependencies:**
   - NPM proxy host entries
   - Grafana/Prometheus monitoring configs
   - Netbox IPAM records
   - SSH config aliases
   - Application configs using hostname
   - Documentation references

2. **Backup current state:**
   - Proxmox container backup
   - Export NPM configuration
   - Export monitoring configs
   - Screenshot current Netbox entries

3. **Communication:**
   - Notify users of downtime (if applicable)
   - Document change in CHANGELOG.md

### Rename Steps

1. **Stop container:**
   ```bash
   pct stop <CTID>
   ```

2. **Rename container:**
   ```bash
   pct set <CTID> --hostname <new-name>
   ```

3. **Update Netbox IPAM:**
   - Update VM/device name
   - Update DNS name
   - Add note with old name

4. **Update NPM proxy hosts:**
   - Update backend hostname
   - Test proxy connectivity

5. **Update monitoring configs:**
   - Prometheus targets
   - Grafana dashboards
   - Alert rules

6. **Update SSH config:**
   ```bash
   # ~/.ssh/config
   Host <new-name>
       HostName <IP>
       User root
       IdentityFile ~/.ssh/id_rsa
   ```

7. **Update documentation:**
   - infrastructure-spec.md
   - Any runbooks or procedures

8. **Start container and test:**
   ```bash
   pct start <CTID>
   # Test service functionality
   # Test proxy access
   # Test monitoring
   ```

9. **Verify all references updated:**
   - Check NPM dashboard
   - Check Grafana dashboards
   - Check Netbox
   - Check application logs

---

## Enforcement

### For New Containers

**MUST follow standard:**
- Use naming convention format
- Use appropriate ID range
- Document in infrastructure-spec.md
- Add to Netbox IPAM

### For Existing Containers

**Rename during:**
- Major version upgrades
- Service migrations
- Infrastructure reorganization
- When inconsistency causes confusion

**Do NOT rename if:**
- Service is production-critical with many dependencies
- Rename would cause significant downtime
- Risk outweighs benefit

---

## Examples by Category

### Media Stack
```
plex (128)
sonarr (125)
radarr (124)
readarr (120)
prowlarr (123)
transmission (126)
sabnzbd (127)
calibre-web (129)
```

### Application Deployments (Blue-Green)
```
theoshift-blue (134)
theoshift-green (132)
ldctools-blue (133)
ldctools-green (135)
quantshift-blue (137)
quantshift-green (138)
```

### Infrastructure
```
postgres-primary (131)
postgres-replica (151)
haproxy (136)
haproxy-standby (139)
nginx-proxy (121)
netbox (118)
adguard (113)
```

### Monitoring
```
monitoring-stack (150)
qa-testing (115)
```

### Development
```
bni-toolkit-dev (119)
```

### Bots & Automation
```
quantshift-bot-primary (100)
quantshift-bot-standby (101)
```

---

## References

- **Infrastructure Spec:** `documentation/infrastructure-spec.md`
- **Netbox IPAM:** `http://netbox.cloudigan.net`
- **Control Plane Governance:** `_cloudy-ops/context/DECISIONS.md`

---

**Last Updated:** 2026-02-22  
**Maintained By:** Infrastructure Team  
**Status:** Active - Apply to all new containers
