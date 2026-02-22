# Implementation Plan - homelab-nexus

**Last Updated:** 2026-02-22  
**Current Phase:** Phase 2 - Automation (Q2 2026)  
**Repository:** Proxmox infrastructure automation and management

---

## 🎯 Active Work (This Week)

**Current Focus:** Repository setup complete. Ready to start Phase 2 automation work.

- [x] Create IMPLEMENTATION-PLAN.md with governance structure (effort: S)
- [x] Create TASK-STATE.md for session tracking (effort: S)
- [x] Sync .cloudy-work submodule to latest (effort: S)
- [x] Consolidate all tracking from README/CHANGELOG (effort: S)
- [ ] Commit new governance-compliant files (effort: S)

---

## 📋 Backlog (Prioritized)

### High Priority

- [ ] **Automated Container Provisioning Pipeline** (effort: L) - End-to-end automation for new container deployment. Components: auto-assign CTID, Netbox IPAM registration, NPM reverse proxy entry, AdGuard DNS entry, Proxmox LXC creation. Reduces deployment from 30+ minutes to <5 minutes. Dependencies: Netbox API, Proxmox API, NPM API.

- [ ] **Container Naming Convention Audit** (effort: S) - Review all 23 container names for consistency. Document current patterns, establish standard naming convention (function-role pattern), identify containers needing rename, create migration plan. Quick win before larger automation work.
  - **Phase 1: Documentation** (30 min)
    - [x] Audit current container names (23 containers)
    - [x] Identify naming patterns and inconsistencies
    - [x] Create standard naming convention document
    - [x] Define CTID/VMID numbering ranges by function
    - [ ] Document rationale for each proposed change
  - **Phase 2: Planning** (1 hour)
    - [ ] Categorize containers by rename priority (8 need rename)
    - [ ] Assess blast radius for each rename (NPM, monitoring, DNS)
    - [ ] Create step-by-step rename procedure
    - [ ] Identify all dependencies per container
  - **Phase 3: Implementation** (2-3 hours)
    - [ ] High priority: Rename 4 containers (theoshift, npm, sandbox)
    - [ ] Update Netbox IPAM records
    - [ ] Update NPM proxy host entries
    - [ ] Update Grafana/Prometheus monitoring configs
    - [ ] Update infrastructure-spec.md
    - [ ] Test each rename before moving to next
  - **Standard Created:** `documentation/container-naming-standard.md`
  - **ID Ranges Defined:** 100-109 Bots, 110-119 Dev, 120-129 Media, 130-139 Core, 140-149 Network, 150-159 Monitoring

### Medium Priority

- [ ] **Container Renumbering Strategy** (effort: M) - Group containers by function using CTID ranges (100-109: Bot/automation, 110-119: Development/sandbox, 130-139: Core infrastructure, 140-149: Media services, 150-159: Monitoring). Assess blast radius, create migration scripts, test in non-production, document rollback. High risk - requires careful planning.

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

- [ ] **TrueNAS Disk Replacement** - **Deferred because:** RMA in progress, waiting for physical disk arrival. **Revisit:** When replacement disk arrives (expected next week). **Action Required:** Replace `/dev/sde` (Seagate ST12000DM0007, serial `ZJV28SCB`). Current state: media-pool DEGRADED with zero redundancy. Steps: (1) Hot-swap disk in Supermicro chassis, (2) TrueNAS UI → Storage → media-pool → Manage Disks → Replace, (3) Wait for resilver (several hours), (4) Verify Prometheus alert resolves, (5) Apply TrueNAS OS update.

---

## ✅ Recently Completed (Last 30 Days)

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

**Last Updated:** 2026-02-22  
**Maintained By:** Infrastructure Team  
**Status:** Active - Following control plane governance standards
