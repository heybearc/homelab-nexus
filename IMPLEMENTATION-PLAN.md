# Implementation Plan - homelab-nexus

**Last Updated:** 2026-03-13 (4:51 PM)  
**Current Phase:** Phase 2 - Automation (Q2 2026)  
**Repository:** Proxmox infrastructure automation and management

---

## 🎯 Active Work (This Week)

**Current Focus:** No active work. Infrastructure maintenance complete. Ready for next project.

**Recent Completions:**
- [x] TrueNAS resilver verification (effort: S) - Mar 13
- [x] VM 107 stuck reboot troubleshooting (effort: S) - Mar 13
- [x] TrueNAS disk replacement (effort: S) - Mar 5
- [x] Complete Phase 3 container renames (8/8 containers) (effort: M) - Feb 23-25
- [x] NPM proxy host audit and cleanup (effort: S) - Feb 23-25
- [x] Governance sync across all repos (effort: S) - Mar 3

---

## 📋 Backlog (Prioritized)

### High Priority

- [ ] **Automated Container Provisioning Pipeline** (effort: L) - End-to-end automation for new container deployment. Components: auto-assign CTID, Netbox IPAM registration, NPM reverse proxy entry, AdGuard DNS entry, Proxmox LXC creation. Reduces deployment from 30+ minutes to <5 minutes. Dependencies: Netbox API, Proxmox API, NPM API.

- [x] **Container Naming Convention Audit** (effort: M) - ✅ COMPLETE - All 8 containers renamed and promoted to control plane. All containers now follow standard naming convention.
  - **Phase 1: Documentation** ✅ COMPLETE
    - [x] Audit current container names (23 containers)
    - [x] Identify naming patterns and inconsistencies
    - [x] Create standard naming convention document
    - [x] Define CTID/VMID numbering ranges by function
  - **Phase 2: Planning** ✅ COMPLETE
    - [x] Categorize containers by rename priority (8 need rename)
    - [x] Assess blast radius for each rename (NPM, monitoring, DNS)
    - [x] Create step-by-step rename procedure
    - [x] Identify all dependencies per container
  - **Phase 3: Implementation** ✅ COMPLETE
    - [x] Renamed all 8 containers (CT119, CT100, CT101, CT118, CT121, CT132, CT134, CT150)
    - [x] Updated Netbox IPAM records (all 8 containers)
    - [x] Updated NPM proxy hosts (verified all 32 working)
    - [x] Updated DNS on DC-01 and AdGuard
    - [x] Updated infrastructure-spec.md and APP-MAP.md
    - [x] Promoted all changes to control plane
  - **Standard Created:** `documentation/container-naming-standard.md`
  - **ID Ranges Defined:** 100-109 Bots, 110-119 Dev, 120-129 Media, 130-139 Core, 140-149 Network, 150-159 Monitoring

### Medium Priority

- [ ] **Container Renumbering Strategy** (effort: M) - ⏳ IN PROGRESS - Migrating containers to correct CTID ranges. Completed: CT113→CT140 (adguard), CT118→CT141 (netbox). Remaining: CT121→CT142 (nginx-proxy) scheduled for tonight. Method: Stop container, rename ZFS volume, rename config file, update rootfs reference, start container. Downtime: ~30 seconds per container.

- [ ] **Infrastructure-as-Code Templates** (effort: L) - Create Terraform/Ansible templates for container provisioning. Enables version-controlled infrastructure, repeatable deployments, disaster recovery.

- [ ] **Backup Automation for All Containers** (effort: M) - Automated backup procedures for all 23 containers. Schedule, retention policy, verification, restore testing.

- [ ] **Enhanced VPN Killswitch** (effort: S) - SSH-preserving VPN killswitch for download clients. Prevents accidental exposure while maintaining management access.

### Low Priority

- [ ] **Disaster Recovery Runbooks** (effort: M) - Document recovery procedures for each critical service. Container recovery, network restoration, service rollback, infrastructure validation.

- [ ] **Performance Optimization Suite** (effort: L) - Resource usage optimization, network performance tuning, storage efficiency improvements.

- [ ] **Security Hardening Implementation** (effort: L) - Container security audit, network segmentation, access control review, credential rotation.

---

## 🐛 Known Bugs

### Critical (Fix Immediately)

None currently.

### Non-Critical (Backlog)

- [ ] **Readarr Service Issues** (effort: M) - Service experiencing issues on CT120 (10.92.3.4). Needs troubleshooting and potential reinstall. Workaround: Manual book management.

- [ ] **SABnzbd VPN Configuration Incomplete** (effort: S) - SABnzbd (CT127) migrated from Docker to LXC but VPN configuration pending. Workaround: Running without VPN temporarily.

---

## 💡 Infrastructure Improvements & Observations

### From Operations

- [ ] **Complete Docker to LXC Migration** (effort: XL) - Remaining Docker services need migration to LXC for consistency and resource efficiency. Affects multiple services.

- [ ] **Advanced Network Segmentation** (effort: L) - Implement additional VLANs for service isolation. Improves security posture and traffic management.

- [ ] **Monitoring and Alerting Improvements** (effort: M) - Enhanced Grafana dashboards, additional Prometheus exporters, alert rule refinement.

---

## 🗺️ Roadmap (Strategic)

### Phase 1: Foundation (Q1 2026) ✅ COMPLETE

- [x] Netbox full buildout (25 VMs, IPs, physical layer, VLANs, services)
- [x] Proxmox→Netbox sync automation (CT150, cron every 15min)
- [x] TrueNAS integration (SSH, API, Prometheus exporter)
- [x] HAProxy VRRP (VIP 10.92.3.33, CT136 MASTER + CT139 BACKUP)
- [x] PostgreSQL streaming replica (CT131 → CT151, watchdog failover)
- [x] Monitoring stack (Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma)
- [x] Watchdog auto-restart (Alertmanager webhook → Proxmox API)
- [x] Container cleanup (removed 4 unused containers: 130, 112, 117, 122)

### Phase 2: Automation (Q2 2026) ⏳ IN PROGRESS

- [ ] Automated container provisioning pipeline
- [ ] Container naming convention standard
- [ ] Infrastructure-as-code templates (Terraform/Ansible)
- [ ] Backup automation for all containers
- [ ] Disaster recovery runbooks
- [ ] Complete Docker to LXC migration

### Phase 3: Optimization (Q3 2026) 📋 PLANNED

- [ ] Container renumbering implementation
- [ ] Resource usage optimization
- [ ] Network performance tuning
- [ ] Storage efficiency improvements
- [ ] Advanced network segmentation
- [ ] Security hardening

### Future (No Timeline)

- [ ] Multi-site replication
- [ ] Automated disaster recovery testing
- [ ] Infrastructure cost optimization
- [ ] Advanced monitoring with ML anomaly detection

---

## 📝 Deferred Items

**Items explicitly deferred with rationale:**

- [ ] **TrueNAS OS Update** - **Deferred because:** Waiting for new drive burn-in period. **Revisit:** Now ready to apply (resilver complete Mar 9, pool ONLINE, 8 days stable). **Action Required:** Apply TrueNAS SCALE Fangtooth update. Current state: media-pool ONLINE with 0 errors. Steps: (1) ✅ Resilver complete, (2) ✅ Pool ONLINE status verified, (3) ✅ Prometheus alerts cleared, (4) ✅ New drive monitored 8 days, (5) Apply OS update via TrueNAS UI.

---

## ✅ Recently Completed (Last 30 Days)

### 2026-03-13
- [x] TrueNAS resilver verification - confirmed complete (100.98%, 0 errors, pool ONLINE) (Date: 2026-03-13)
- [x] TrueNAS alerts verification - all pool degraded and disk faulted alerts cleared (Date: 2026-03-13)
- [x] VM 107 troubleshooting - resolved stuck reboot loop (killed task, removed lock, force stopped) (Date: 2026-03-13)

### 2026-03-05
- [x] TrueNAS disk replacement - replaced failed drive (serial ZJV28SCB) with enterprise SAS drive (serial WV70FDPJ) (Date: 2026-03-05)
- [x] SMART health verification - new drive passed all tests with 0 errors, 0 power-on hours (Date: 2026-03-05)
- [x] Resilver initiated - 32TB to process, 0 errors, 8-12 hour ETA (Date: 2026-03-05)

### 2026-02-25
- [x] CTID Migration: CT113 → CT140 (adguard) to Network Services range (Date: 2026-02-25)
- [x] CTID Migration: CT118 → CT141 (netbox) to Network Services range (Date: 2026-02-25)
- [x] Created CT121 → CT142 migration plan for nginx-proxy (Date: 2026-02-25)
- [x] Updated infrastructure-spec.md for CTID migrations (Date: 2026-02-25)

### 2026-02-23
- [x] NPM proxy host audit and cleanup - deleted 35 obsolete hosts (Date: 2026-02-23)
- [x] NPM SSL force enabled for all 32 proxy hosts with certificates (Date: 2026-02-23)
- [x] NPM automated backup system to TrueNAS NFS (Date: 2026-02-23)
- [x] Phase 3 container renames - all 8 containers completed (Date: 2026-02-23)
- [x] Control plane sync - APP-MAP.md updated with all renames (Date: 2026-02-23)
- [x] Created NPM-BACKUP-RECOVERY-PLAN.md documentation (Date: 2026-02-23)

### 2026-02-22
- [x] Created governance-compliant IMPLEMENTATION-PLAN.md (Date: 2026-02-22)
- [x] Created TASK-STATE.md for session tracking (Date: 2026-02-22)
- [x] Synced .cloudy-work submodule to latest (020f626 → 800cd1d) (Date: 2026-02-22)
- [x] Consolidated all tracking info from README/CHANGELOG (Date: 2026-02-22)

### 2026-02-21 — TrueNAS Integration & Resilience Stack
- [x] TrueNAS: SSH keyless access, API key, app scan (Date: 2026-02-21)
- [x] TrueNAS: app updates — Vaultwarden 1.5.2, Nextcloud 32.0.6 (Date: 2026-02-21)
- [x] TrueNAS: custom Prometheus exporter CT150:9200, 6 alert rules (Date: 2026-02-21)
- [x] Grafana: TrueNAS dashboard (pool health, disk status, app state) (Date: 2026-02-21)
- [x] Netbox: full buildout — 25 VMs, IPs, physical layer, VLANs, services (Date: 2026-02-21)
- [x] Proxmox→Netbox sync: CT150 cron every 15min (Date: 2026-02-21)
- [x] HAProxy VRRP: CT136 MASTER + CT139 BACKUP, VIP 10.92.3.33 (Date: 2026-02-21)
- [x] PostgreSQL streaming replica: CT131 → CT151, watchdog failover (Date: 2026-02-21)
- [x] Watchdog: Alertmanager webhook → auto-restart containers (Date: 2026-02-21)
- [x] Uptime Kuma: CT150, 18 monitors configured (Date: 2026-02-21)
- [x] Proxmox container cleanup: removed 4 unused containers (130, 112, 117, 122) (Date: 2026-02-21)
- [x] Promoted infrastructure cleanup documentation to control plane (Date: 2026-02-21)

---

## 📊 Effort Sizing Guide

- **S (Small):** 1-4 hours - Quick fixes, minor configuration changes, documentation updates
- **M (Medium):** 1-2 days - Standard automation scripts, moderate infrastructure changes
- **L (Large):** 3-5 days - Complex automation pipelines, major infrastructure additions
- **XL (Extra Large):** 1+ weeks - Complete system migrations, architectural overhauls

---

## 📚 Infrastructure Reference

- **Proxmox Host:** 10.92.0.5
- **Active Containers:** 23 (down from 27 after Feb 21 cleanup)
- **Storage:** 20.62TB across 4 storage pools
- **Networks:** Management (10.92.0.0/23), Services (10.92.3.0/24)
- **Control Plane Governance:** `_cloudy-ops/context/DECISIONS.md`
- **Homelab Backlog:** `_cloudy-ops/docs/infrastructure/homelab-backlog.md`
- **Monitoring:** Grafana at `grafana.cloudigan.net`
- **IPAM:** Netbox at `netbox.cloudigan.net` (source of truth for all IP assignments)

---

**Last Updated:** 2026-02-25  
**Maintained By:** Infrastructure Team  
**Status:** Active - Following control plane governance standards
