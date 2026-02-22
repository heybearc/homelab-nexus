# homelab-nexus Implementation Plan

**Last Updated:** 2026-02-22  
**Repository:** homelab-nexus  
**Purpose:** Proxmox infrastructure automation and management

---

## Active Work

**Current Focus:** Automated container provisioning pipeline

---

## Backlog

### 🔴 High Priority

#### Automated Container Provisioning Pipeline
- **Description:** End-to-end automation for new container deployment
- **Components:**
  - Auto-assign next available CTID
  - Netbox IPAM registration (IP assignment, VM record, tags)
  - NPM reverse proxy entry creation
  - Internal DNS entry (AdGuard)
  - Proxmox LXC creation with standard template
- **Effort:** L (Large - 8-16 hours)
- **Dependencies:** Netbox API, Proxmox API, NPM API
- **Value:** Reduces container deployment from 30+ minutes to <5 minutes
- **Reference:** `_cloudy-ops/docs/infrastructure/homelab-backlog.md`

---

### 🟡 Medium Priority

#### Container Naming Convention Audit
- **Description:** Review all 25 container names for consistency
- **Tasks:**
  - Document current naming patterns
  - Establish standard naming convention (function-role pattern)
  - Identify containers needing rename
  - Create migration plan
- **Effort:** S (Small - 2-4 hours)
- **Value:** Improves clarity and reduces cognitive load

#### Container Renumbering Strategy
- **Description:** Group containers by function using CTID ranges
- **Proposed ranges:**
  - 100-109: Bot/automation containers
  - 110-119: Development/sandbox
  - 130-139: Core infrastructure (DB, HAProxy, Redis)
  - 140-149: Media services
  - 150-159: Monitoring/observability
- **Tasks:**
  - Assess blast radius for each container
  - Create migration scripts
  - Test in non-production first
  - Document rollback procedures
- **Effort:** M (Medium - 4-8 hours)
- **Risk:** High - requires careful planning and testing
- **Value:** Logical organization, easier to remember

---

## Known Bugs

None currently tracked.

---

## User Feedback

No feedback system implemented for infrastructure repo.

---

## Roadmap

### Phase 1: Foundation (Q1 2026) ✅ COMPLETE
- ✅ Netbox full buildout (25 VMs, IPs, physical layer, VLANs, services)
- ✅ Proxmox→Netbox sync automation (CT150, cron every 15min)
- ✅ TrueNAS integration (SSH, API, Prometheus exporter)
- ✅ HAProxy VRRP (VIP 10.92.3.33, CT136 MASTER + CT139 BACKUP)
- ✅ PostgreSQL streaming replica (CT131 → CT151, watchdog failover)
- ✅ Monitoring stack (Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma)
- ✅ Watchdog auto-restart (Alertmanager webhook → Proxmox API)

### Phase 2: Automation (Q2 2026) ⏳ PLANNED
- ⏳ Automated container provisioning pipeline
- ⏳ Container naming convention standard
- ⏳ Infrastructure-as-code templates (Terraform/Ansible)
- ⏳ Backup automation for all containers
- ⏳ Disaster recovery runbooks

### Phase 3: Optimization (Q3 2026) 📋 BACKLOG
- 📋 Container renumbering implementation
- 📋 Resource usage optimization
- 📋 Network performance tuning
- 📋 Storage efficiency improvements

---

## Deferred Items

### TrueNAS Disk Replacement
- **Status:** DEFERRED — RMA in progress, disk arriving next week
- **Action Required:** Replace `/dev/sde` (Seagate ST12000DM0007, serial `ZJV28SCB`)
- **Current State:** media-pool DEGRADED with zero redundancy
- **Steps after disk arrives:**
  1. Hot-swap `/dev/sde` in Supermicro chassis
  2. TrueNAS UI → Storage → media-pool → Manage Disks → Replace
  3. Wait for resilver (several hours for 12TB)
  4. Verify Prometheus `TrueNASPoolDegraded` alert resolves
  5. Apply TrueNAS OS update via System → Update
- **Blocked by:** Physical disk arrival (external dependency)

---

## Recently Completed

### 2026-02-21 — TrueNAS Integration & Resilience Stack
- ✅ TrueNAS: SSH keyless access, API key, app scan
- ✅ TrueNAS: app updates — Vaultwarden 1.5.2, Nextcloud 32.0.6
- ✅ TrueNAS: custom Prometheus exporter CT150:9200, 6 alert rules
- ✅ Grafana: TrueNAS dashboard (pool health, disk status, app state)
- ✅ Netbox: full buildout — 25 VMs, IPs, physical layer, VLANs, services, VMIDs
- ✅ Netbox: TrueNAS physical device, apps IP 10.92.5.200, services
- ✅ Proxmox→Netbox sync: CT150 cron every 15min (D-026)
- ✅ Control plane: D-027 TrueNAS API integration documented
- ✅ HAProxy VRRP: CT136 MASTER + CT139 BACKUP, VIP 10.92.3.33
- ✅ PostgreSQL streaming replica: CT131 → CT151, failover wired into watchdog
- ✅ Watchdog: Alertmanager webhook → auto-restart containers via Proxmox API
- ✅ Uptime Kuma: CT150, 18 monitors configured
- ✅ NPM + DNS updated to VIP 10.92.3.33

---

## Notes

- **Control plane governance:** All homelab infrastructure decisions documented in `_cloudy-ops/context/DECISIONS.md`
- **Homelab backlog:** Canonical source at `_cloudy-ops/docs/infrastructure/homelab-backlog.md`
- **Monitoring:** All infrastructure monitored via Grafana at `grafana.cloudigan.net`
- **IPAM:** Netbox is source of truth for all IP assignments at `netbox.cloudigan.net`
