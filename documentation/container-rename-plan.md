# Container Rename Execution Plan - Phase 2

**Created:** 2026-02-22  
**Status:** Planning Complete - Ready for Phase 3 Implementation  
**Scope:** 8 containers requiring rename for consistency

---

## Overview

This document provides the detailed execution plan for renaming 8 containers to comply with the new naming standard. Each container has been analyzed for dependencies, blast radius, and risk level.

---

## Containers to Rename

### High Priority (4 containers)

| CTID | Current Name | New Name | Risk Level | Downtime |
|------|--------------|----------|------------|----------|
| 132 | green-theoshift | theoshift-green | Medium | ~2 min |
| 134 | blue-theoshift | theoshift-blue | Medium | ~2 min |
| 121 | npm | nginx-proxy | Low | ~1 min |
| 119 | sandbox-01 | bni-toolkit-dev | Low | ~1 min |

### Medium Priority (4 containers)

| CTID | Current Name | New Name | Risk Level | Downtime |
|------|--------------|----------|------------|----------|
| 150 | monitor | monitoring-stack | Low | ~1 min |
| 118 | netbox-ipam | netbox | Low | ~1 min |
| 100 | quantshift-primary | quantshift-bot-primary | Low | ~1 min |
| 101 | quantshift-standby | quantshift-bot-standby | Low | ~1 min |

---

## Dependency Analysis

### CT132: green-theoshift → theoshift-green

**Dependencies Found:**
- ✅ **Prometheus:** Uses IP-based targeting (10.92.3.22), label is `theoshift-green` (already correct!)
- ✅ **Proxmox LXC config:** `/etc/pve/lxc/132.conf` - hostname field only
- ⚠️ **HAProxy:** May reference hostname for backend (need to verify)
- ⚠️ **Netbox IPAM:** Device/VM name needs update
- ⚠️ **Documentation:** infrastructure-spec.md, APP-MAP.md

**Blast Radius:** Low-Medium
- Prometheus already uses correct label
- HAProxy uses IP-based backends (likely safe)
- No NPM proxy entries (uses HAProxy VIP)

**Risk Assessment:** Medium (production app, but blue-green means standby available)

---

### CT134: blue-theoshift → theoshift-blue

**Dependencies Found:**
- ✅ **Prometheus:** Uses IP-based targeting (10.92.3.24), label is `theoshift-blue` (already correct!)
- ✅ **Proxmox LXC config:** `/etc/pve/lxc/134.conf` - hostname field only
- ⚠️ **HAProxy:** May reference hostname for backend (need to verify)
- ⚠️ **Netbox IPAM:** Device/VM name needs update
- ⚠️ **Documentation:** infrastructure-spec.md, APP-MAP.md

**Blast Radius:** Low-Medium
- Prometheus already uses correct label
- HAProxy uses IP-based backends (likely safe)
- No NPM proxy entries (uses HAProxy VIP)

**Risk Assessment:** Medium (production app, but blue-green means standby available)

---

### CT121: npm → nginx-proxy

**Dependencies Found:**
- ✅ **Prometheus:** No scrape target (NPM not monitored)
- ✅ **Proxmox LXC config:** `/etc/pve/lxc/121.conf` - hostname field only
- ⚠️ **Netbox IPAM:** Device/VM name needs update
- ⚠️ **Documentation:** infrastructure-spec.md, APP-MAP.md, README.md
- ⚠️ **SSH config:** May have alias in ~/.ssh/config

**Blast Radius:** Low
- NPM is infrastructure service, not monitored by Prometheus
- No proxy entries pointing TO npm (it's the proxy itself)
- Standalone service with no inter-container dependencies

**Risk Assessment:** Low (can rename without affecting other services)

---

### CT119: sandbox-01 → bni-toolkit-dev

**Dependencies Found:**
- ✅ **Prometheus:** Uses IP-based targeting (10.92.3.13), label is `qa-01` (different container!)
- ✅ **Proxmox LXC config:** `/etc/pve/lxc/119.conf` - hostname field only
- ⚠️ **Netbox IPAM:** Device/VM name needs update
- ⚠️ **Documentation:** infrastructure-spec.md, APP-MAP.md
- ⚠️ **SSH config:** May have alias in ~/.ssh/config

**Blast Radius:** Low
- Development/sandbox container, non-production
- No monitoring configured
- No dependencies from other services

**Risk Assessment:** Low (development container, safe to rename)

---

### CT150: monitor → monitoring-stack

**Dependencies Found:**
- ✅ **Prometheus:** Self-monitoring uses label `monitor` (need to update)
- ✅ **Proxmox LXC config:** `/etc/pve/lxc/150.conf` - hostname field only
- ⚠️ **Prometheus config:** `/etc/prometheus/prometheus.yml` - label update needed
- ⚠️ **Netbox IPAM:** Device/VM name needs update
- ⚠️ **Documentation:** infrastructure-spec.md, APP-MAP.md
- ⚠️ **SSH config:** Likely has alias in ~/.ssh/config

**Blast Radius:** Low
- Monitoring container itself
- Self-monitoring label needs update in prometheus.yml
- No other services depend on this hostname

**Risk Assessment:** Low (can update label after rename)

---

### CT118: netbox-ipam → netbox

**Dependencies Found:**
- ✅ **Prometheus:** No scrape target (Netbox not monitored)
- ✅ **Proxmox LXC config:** `/etc/pve/lxc/118.conf` - hostname field only
- ⚠️ **NPM:** Proxy entry `netbox.cloudigan.net` → 10.92.3.18 (IP-based, safe)
- ⚠️ **Netbox IPAM:** Device/VM name needs update (self-reference!)
- ⚠️ **Documentation:** infrastructure-spec.md, APP-MAP.md
- ⚠️ **SSH config:** May have alias in ~/.ssh/config

**Blast Radius:** Low
- NPM uses IP-based proxy (safe)
- No monitoring configured
- Self-contained service

**Risk Assessment:** Low (can rename without affecting proxy)

---

### CT100: quantshift-primary → quantshift-bot-primary

**Dependencies Found:**
- ✅ **Prometheus:** Uses IP-based targeting (10.92.3.27), label is `qs-primary` (different from hostname)
- ✅ **Proxmox LXC config:** `/etc/pve/lxc/100.conf` - hostname field only
- ⚠️ **Netbox IPAM:** Device/VM name needs update
- ⚠️ **Documentation:** infrastructure-spec.md, APP-MAP.md
- ⚠️ **SSH config:** May have alias in ~/.ssh/config

**Blast Radius:** Low
- Prometheus uses abbreviated label `qs-primary` (no change needed)
- Bot container, no web interface
- No NPM proxy entries

**Risk Assessment:** Low (bot container, minimal dependencies)

---

### CT101: quantshift-standby → quantshift-bot-standby

**Dependencies Found:**
- ✅ **Prometheus:** Uses IP-based targeting (10.92.3.28), label is `qs-standby` (different from hostname)
- ✅ **Proxmox LXC config:** `/etc/pve/lxc/101.conf` - hostname field only
- ⚠️ **Netbox IPAM:** Device/VM name needs update
- ⚠️ **Documentation:** infrastructure-spec.md, APP-MAP.md
- ⚠️ **SSH config:** May have alias in ~/.ssh/config

**Blast Radius:** Low
- Prometheus uses abbreviated label `qs-standby` (no change needed)
- Standby bot container, not actively running
- No NPM proxy entries

**Risk Assessment:** Low (standby container, minimal impact)

---

## Execution Order (Recommended)

### Batch 1: Low Risk, Non-Production (Start Here)
1. **CT119:** sandbox-01 → bni-toolkit-dev (dev container)
2. **CT101:** quantshift-standby → quantshift-bot-standby (standby bot)
3. **CT100:** quantshift-primary → quantshift-bot-primary (bot, low dependency)

### Batch 2: Infrastructure Services
4. **CT121:** npm → nginx-proxy (standalone infrastructure)
5. **CT118:** netbox-ipam → netbox (standalone infrastructure)
6. **CT150:** monitor → monitoring-stack (requires prometheus.yml update)

### Batch 3: Production Apps (Blue-Green, Do Last)
7. **CT132:** green-theoshift → theoshift-green (verify HAProxy first)
8. **CT134:** blue-theoshift → theoshift-blue (verify HAProxy first)

**Rationale:** Start with lowest risk, build confidence, end with production apps that have blue-green redundancy.

---

## Pre-Execution Checklist

### Before Starting ANY Rename

- [ ] Backup all container configs: `vzdump <CTID> --mode snapshot`
- [ ] Export Netbox data: API backup or manual export
- [ ] Screenshot current Prometheus targets page
- [ ] Screenshot current Grafana dashboards
- [ ] Verify HAProxy backend configuration (for TheoShift containers)
- [ ] Check SSH config for aliases: `grep -E 'npm|sandbox|monitor|netbox|quantshift|theoshift' ~/.ssh/config`
- [ ] Notify team of planned changes (if applicable)

### Required Tools/Access

- [ ] SSH access to Proxmox host (prox)
- [ ] Netbox admin access (http://netbox.cloudigan.net)
- [ ] Prometheus access (http://10.92.3.2:9090)
- [ ] Grafana access (http://grafana.cloudigan.net)
- [ ] HAProxy access (for TheoShift verification)

---

## Rename Procedure (Per Container)

### Step 1: Pre-Rename Verification
```bash
# Check current hostname
ssh prox "pct exec <CTID> -- hostname"

# Verify container is running
ssh prox "pct status <CTID>"

# Check Netbox for current entry
# (Manual: http://netbox.cloudigan.net)
```

### Step 2: Stop Container
```bash
ssh prox "pct stop <CTID>"
```

### Step 3: Rename in Proxmox
```bash
ssh prox "pct set <CTID> --hostname <new-name>"
```

### Step 4: Start Container
```bash
ssh prox "pct start <CTID>"
```

### Step 5: Verify Hostname Inside Container
```bash
ssh prox "pct exec <CTID> -- hostname"
# Should show new name
```

### Step 6: Update Netbox IPAM
1. Navigate to http://netbox.cloudigan.net
2. Find VM/Device by IP or old name
3. Update name field to new name
4. Add note: "Renamed from <old-name> on 2026-02-22"
5. Save changes

### Step 7: Update Prometheus Config (If Needed)
```bash
# Only for CT150 (monitor → monitoring-stack)
ssh prox "pct exec 150 -- nano /etc/prometheus/prometheus.yml"
# Change label from 'monitor' to 'monitoring-stack'
ssh prox "pct exec 150 -- systemctl reload prometheus"
```

### Step 8: Update Documentation
```bash
# Update infrastructure-spec.md
# Update APP-MAP.md (in .cloudy-work)
# Update container-naming-standard.md (mark as complete)
```

### Step 9: Update SSH Config (If Exists)
```bash
# Edit ~/.ssh/config locally
# Update any Host entries with old name
```

### Step 10: Verify Service Functionality
```bash
# Test service is running
ssh prox "pct exec <CTID> -- systemctl status <service>"

# Test network connectivity
ping <IP>

# Test web interface (if applicable)
curl http://<IP>:<port>

# Check Prometheus targets (if monitored)
# Navigate to http://10.92.3.2:9090/targets
```

### Step 11: Document Completion
- [ ] Mark container as renamed in this document
- [ ] Update TASK-STATE.md with completion
- [ ] Commit documentation changes

---

## Rollback Procedure (If Needed)

If a rename causes issues:

```bash
# 1. Stop container
ssh prox "pct stop <CTID>"

# 2. Revert hostname
ssh prox "pct set <CTID> --hostname <old-name>"

# 3. Start container
ssh prox "pct start <CTID>"

# 4. Revert Netbox changes
# (Manual: restore old name in Netbox UI)

# 5. Revert Prometheus config (if changed)
ssh prox "pct exec 150 -- nano /etc/prometheus/prometheus.yml"
ssh prox "pct exec 150 -- systemctl reload prometheus"

# 6. Test service functionality
```

---

## Rename Progress Tracker

### Batch 1: Low Risk, Non-Production
- [ ] CT119: sandbox-01 → bni-toolkit-dev
- [ ] CT101: quantshift-standby → quantshift-bot-standby
- [ ] CT100: quantshift-primary → quantshift-bot-primary

### Batch 2: Infrastructure Services
- [ ] CT121: npm → nginx-proxy
- [ ] CT118: netbox-ipam → netbox
- [ ] CT150: monitor → monitoring-stack (requires prometheus.yml update)

### Batch 3: Production Apps
- [ ] CT132: green-theoshift → theoshift-green (verify HAProxy first)
- [ ] CT134: blue-theoshift → theoshift-blue (verify HAProxy first)

---

## Key Findings Summary

### Good News ✅
1. **Prometheus uses IP-based targeting** - No hostname dependencies in scrape configs
2. **Prometheus labels already correct** - TheoShift labels are `theoshift-blue/green` (matches new names!)
3. **NPM uses IP-based proxies** - No hostname dependencies in proxy configs
4. **Most containers are standalone** - Limited inter-container dependencies

### Requires Attention ⚠️
1. **Netbox IPAM** - All 8 containers need manual name update in Netbox UI
2. **Documentation** - infrastructure-spec.md and APP-MAP.md need updates
3. **SSH config** - May have aliases that need updating
4. **HAProxy** - Need to verify TheoShift backend config before renaming
5. **CT150 Prometheus config** - Label needs update from `monitor` to `monitoring-stack`

### Low Risk Assessment 🎯
- **Total downtime per container:** ~1-2 minutes
- **Service disruption:** Minimal (IP-based dependencies)
- **Rollback capability:** Easy (just revert hostname)
- **Testing required:** Basic service health check after each rename

---

## Next Steps

**Phase 2 Complete ✅** - Ready to proceed to Phase 3 (Implementation)

**Recommended Approach:**
1. Start with Batch 1 (3 low-risk containers)
2. Verify process works smoothly
3. Continue to Batch 2 (3 infrastructure containers)
4. Finish with Batch 3 (2 production apps after HAProxy verification)

**Estimated Total Time:** 2-3 hours for all 8 containers (including testing and documentation)

---

**Last Updated:** 2026-02-22  
**Status:** Planning Complete - Awaiting Phase 3 Execution Approval
