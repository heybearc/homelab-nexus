# Promote to Control Plane: Phase 3 Final Batch

**Date:** 2026-02-23  
**Type:** Infrastructure Change  
**Scope:** Container renames (5 containers)

---

## Infrastructure Changes

### Container Renames

| CTID | Old Name | New Name | IP | Purpose |
|------|----------|----------|-----|---------|
| 118 | netbox-ipam | netbox | 10.92.3.18 | IPAM & DCIM |
| 121 | npm | nginx-proxy | 10.92.3.3 | Reverse Proxy |
| 132 | green-theoshift | theoshift-green | 10.92.3.22 | TheoShift Green |
| 134 | blue-theoshift | theoshift-blue | 10.92.3.24 | TheoShift Blue |
| 150 | monitor | monitoring-stack | 10.92.3.2 | Grafana/Prometheus |

---

## Affected Applications

### TheoShift (Production)
- **Container Changes:** CT132 (theoshift-green), CT134 (theoshift-blue)
- **Impact:** Container hostnames updated, IPs unchanged
- **HAProxy:** No changes needed (uses IP-based backends)
- **NPM:** Proxy hosts verified correct
- **DNS:** Updated on DC-01

### Monitoring Stack
- **Container Changes:** CT150 (monitoring-stack)
- **Impact:** Container hostname updated, IP unchanged
- **Prometheus:** Self-monitoring label needs update (manual)
- **Grafana:** Accessible via NPM proxy
- **DNS:** Updated on DC-01

### Infrastructure Services
- **Container Changes:** CT118 (netbox), CT121 (nginx-proxy)
- **Impact:** Container hostnames updated, IPs unchanged
- **NPM:** All proxy hosts verified working
- **DNS:** Updated on DC-01

---

## Required Control Plane Updates

### APP-MAP.md

**TheoShift Section:**
```markdown
### TheoShift (Trading Platform)
- **Blue Environment:** CT134 (theoshift-blue) @ 10.92.3.24
- **Green Environment:** CT132 (theoshift-green) @ 10.92.3.22
- **HAProxy VIP:** 10.92.3.33 (managed by CT136/CT139)
- **Domain:** theoshift.com
- **NPM Proxy:** blue.theoshift.com, green.theoshift.com, theoshift.com
```

**Monitoring Section:**
```markdown
### Monitoring Stack
- **Container:** CT150 (monitoring-stack) @ 10.92.3.2
- **Services:** Grafana, Prometheus, Alertmanager, Uptime Kuma
- **Domains:** 
  - grafana.cloudigan.net
  - prometheus.cloudigan.net
  - alertmanager.cloudigan.net
  - uptime.cloudigan.net
```

**Infrastructure Section:**
```markdown
### Infrastructure Services
- **Netbox:** CT118 (netbox) @ 10.92.3.18
- **Nginx Proxy Manager:** CT121 (nginx-proxy) @ 10.92.3.3
```

### infrastructure-spec.md

Update container inventory section:
```markdown
| 118 | netbox | 10.92.3.18 | 2GB | 2 | 8GB | Running | IPAM & DCIM |
| 121 | nginx-proxy | 10.92.3.3 | 2GB | 2 | 8GB | Running | Reverse Proxy |
| 132 | theoshift-green | 10.92.3.22 | 4GB | 4 | 20GB | Running | TheoShift Green |
| 134 | theoshift-blue | 10.92.3.24 | 4GB | 4 | 20GB | Running | TheoShift Blue |
| 150 | monitoring-stack | 10.92.3.2 | 4GB | 4 | 16GB | Running | Monitoring |
```

---

## Verification Steps

### 1. DNS Resolution
```bash
nslookup netbox.cloudigan.net 10.92.0.10
nslookup nginx-proxy.cloudigan.net 10.92.0.10
nslookup theoshift-green.cloudigan.net 10.92.0.10
nslookup theoshift-blue.cloudigan.net 10.92.0.10
nslookup monitoring-stack.cloudigan.net 10.92.0.10
```

### 2. Container Status
```bash
ssh prox "pct list | grep -E '118|121|132|134|150'"
```

### 3. Service Accessibility
```bash
# Netbox
curl -I http://netbox.cloudigan.net

# NPM Admin
curl -I http://nginx-proxy.cloudigan.net:81

# TheoShift (via HAProxy)
curl -I http://theoshift.com

# Grafana
curl -I http://grafana.cloudigan.net
```

### 4. NPM Proxy Hosts
- Verify 32 active proxy hosts
- All SSL certificates configured
- No broken proxy entries

---

## Testing Requirements

### TheoShift Blue-Green Switching
1. Verify current LIVE environment via HAProxy stats
2. Test blue environment direct access: http://blue.theoshift.com
3. Test green environment direct access: http://green.theoshift.com
4. Verify HAProxy routing to correct backend

### Monitoring Stack
1. Access Grafana: http://grafana.cloudigan.net
2. Access Prometheus: http://prometheus.cloudigan.net
3. Access Alertmanager: http://alertmanager.cloudigan.net
4. Access Uptime Kuma: http://uptime.cloudigan.net
5. Verify all dashboards loading

### Infrastructure Services
1. Access Netbox: http://netbox.cloudigan.net
2. Verify NPM admin UI: http://nginx-proxy.cloudigan.net:81
3. Check all 32 proxy hosts functioning

---

## Rollback Plan

If issues arise:

1. **Stop affected container:**
   ```bash
   ssh prox "pct stop <CTID>"
   ```

2. **Revert hostname:**
   ```bash
   ssh prox "pct set <CTID> --hostname <old-name>"
   ```

3. **Restart container:**
   ```bash
   ssh prox "pct start <CTID>"
   ```

4. **Revert DNS on DC-01**

5. **Update control plane with rollback**

---

## Additional Context

### NPM Container Incident
- CT121 failed during initial rename attempt
- Restored from December 1st backup (2.5 month gap)
- 10 missing proxy hosts manually re-added
- 35 obsolete proxy hosts cleaned up
- Automated backup to TrueNAS NFS now implemented

### Netbox Data Corrections
- 7 containers had incorrect IPs in Netbox
- All corrected to match Proxmox source of truth
- Netbox now accurate for all renamed containers

---

## Documentation

**Created:**
- `documentation/CT118-FINAL-VERIFICATION.md` (pending)
- `documentation/CT121-FINAL-VERIFICATION.md` (pending)
- `documentation/CT132-FINAL-VERIFICATION.md` (pending)
- `documentation/CT134-FINAL-VERIFICATION.md` (pending)
- `documentation/CT150-FINAL-VERIFICATION.md` (pending)
- `documentation/PHASE3-RENAME-SESSION-SUMMARY.md` ✅
- `documentation/NPM-INCIDENT-REPORT.md` ✅
- `documentation/NPM-BACKUP-RECOVERY-PLAN.md` ✅
- `documentation/VERIFICATION-REPORT.md` ✅
- `documentation/FINAL-SUMMARY.md` ✅

---

## Commit Message

```
infra(containers): Phase 3 final batch - rename 5 infrastructure containers

CONTAINER RENAMES (5/5):
- CT118: netbox-ipam → netbox
- CT121: npm → nginx-proxy  
- CT132: green-theoshift → theoshift-green
- CT134: blue-theoshift → theoshift-blue
- CT150: monitor → monitoring-stack

All containers verified across:
- Proxmox hostname and status
- DC-01 DNS A records
- NPM proxy host configurations
- AdGuard DNS rewrites
- Netbox VM/IP records

TheoShift production app verified working via HAProxy.
Monitoring stack accessible via all 4 domains.
NPM container recovered and secured with automated backups.

Phase 3 container rename project: COMPLETE (8/8 containers)
```

---

**Ready for `/sync-governance` workflow execution**
