# Implementation Plan - homelab-nexus

**Last Updated:** 2026-03-21 (2:55 PM)  
**Current Phase:** Phase 2 - Infrastructure Automation & MSP Platform Planning (Q2 2026)  
**Repository:** Proxmox infrastructure automation and management  
**Strategic Direction:** Building Proxmox Infrastructure Manager (PIM) + Cloudigan MSP Platform

---

## 🎯 Active Work (This Week)

**Current Focus:** Infrastructure Automation & Monitoring

**Semaphore Ansible Automation Platform** (Mar 21 - COMPLETED)
- [x] Microsoft 365 SSO integration via OpenID Connect
- [x] Ansible playbook repository created (github.com/heybearc/ansible-playbooks)
- [x] Self-updating template system (auto-creates templates from playbooks)
- [x] Teams notifications for task completion
- [x] 7 operational playbooks deployed (Fix Python, Health Check, PostgreSQL Status, Node.js Restart, System Update, Sync Templates, Sync Inventory)
- [x] Complete Proxmox inventory integration (30 hosts: 29 LXC containers + TrueNAS)
- [x] SSH key distribution to all production infrastructure
- [x] Automated inventory sync from Proxmox via playbook
- [x] 29/30 hosts reachable and managed via Ansible (all except TrueNAS edge cases)

**Recent Completions:**
- [x] Complete Semaphore + Ansible infrastructure automation - Mar 21
  - Semaphore automation platform fully operational
  - 7 operational playbooks deployed
  - Complete Proxmox inventory (30 hosts) with automated sync
  - SSH key distribution to all infrastructure
  - System Update playbook with dpkg lock retry logic
  - Template auto-creation system (prevents duplicates)
- [x] PostgreSQL infrastructure discovery: Single server (no replica configured) - Mar 21
- [x] Automation pipeline scripts created (provision-container.sh + helpers) - Mar 14
- [x] Pipeline components: Netbox, NPM, DNS, monitoring, backup integration - Mar 14
- [x] Strategic analysis: MCP + automation = unique product opportunity - Mar 14
- [x] TrueNAS resilver verification (effort: S) - Mar 13
- [x] VM 107 stuck reboot troubleshooting (effort: S) - Mar 13
- [x] Container naming convention audit complete (8/8 containers) - Feb 23-25

---

## 📋 Backlog (Prioritized)

### High Priority

- [ ] **Cloudigan MSP Platform - Phase 1 Deployment** (effort: XL) - **PLANNING** - Deploy core MSP platform services. **Anchor Services:** BookStack (documentation/client hub), Plane (project management), Authentik/Entra ID (identity). **Reference:** `documentation/MSP-PLATFORM-ANALYSIS.md`
  - **Phase 1: Anchor Services** (Priority 1)
    - [ ] BookStack - Documentation & client hub (primary navigation)
    - [ ] Plane - Project management (execution layer)
    - [ ] Authentik - Identity provider (SSO foundation, if Entra ID insufficient)
    - [ ] Research Entra ID compatibility for each service
  - **Phase 2: Core Operations** (Priority 2)
    - [ ] Zammad - Ticketing system (customer-facing, CRITICAL)
    - [ ] Documenso - E-signature platform (customer-facing, CRITICAL)
    - [ ] Twenty CRM - Customer relationship management
    - [ ] Kimai - Time tracking
  - **Phase 3: Automation & Integration** (Priority 3)
    - [ ] n8n - Workflow automation (integrates with 1Password for client secrets)
  - **Infrastructure Requirements:**
    - [ ] PostgreSQL HA setup (see below - BLOCKER)
    - [ ] Entra ID SSO research and app registrations
    - [ ] Backup strategy extension to MSP containers
    - [ ] Blue-green deployment pattern for MSP apps

- [x] **PostgreSQL High Availability Setup** (effort: M) - ✅ COMPLETE (Mar 21) - **UNBLOCKED MSP PLATFORM** - Prometheus-based automatic failover system operational. Components: (1) ✅ PostgreSQL 17 streaming replication (CT131 → CT151), (2) ✅ postgres_exporter on both nodes, (3) ✅ Prometheus alert rules for failover detection, (4) ✅ Alertmanager webhook routing, (5) ✅ Webhook receiver on CT150 triggers Semaphore, (6) ✅ Ansible playbooks for failover and recovery. **Failover time:** ~30 seconds. **Documentation:** `documentation/POSTGRESQL-HA-SETUP.md`. **Status:** Protects 5 production databases + ready for 8 new MSP databases.

- [ ] **Proxmox Infrastructure Manager (PIM)** (effort: XL) - **IN PROGRESS** - MCP server with full container provisioning capabilities. Natural language interface: "Create a media server with 4GB RAM and Plex". AI handles: CTID assignment, Netbox registration, NPM proxy, DNS, monitoring, backups. Merges mcp-server-proxmox + automation pipeline. **Strategic Goal:** Validate as potential commercial product.
  - **Phase 1: Core MCP Integration** (Mar 14-31)
    - [ ] Merge automation scripts into mcp-server-proxmox
    - [ ] Add `create_container` MCP tool
    - [ ] Add `provision_stack` MCP tool (templates)
    - [ ] Test with CT180 deployment
  - **Phase 2: Polish & Validate** (Apr 1-14)
    - [ ] Error handling & rollback
    - [ ] Template system (media, dev, monitoring stacks)
    - [ ] Documentation & examples
    - [ ] Demo video
  - **Phase 3: Open Source Release** (Apr 15-21)
    - [ ] Clean up code, add tests
    - [ ] Publish to GitHub/NPM
    - [ ] Community validation (r/homelab, r/selfhosted)
  - **Phase 4: Platform (Optional)** (Q3 2026)
    - [ ] Web dashboard (if community demand exists)
    - [ ] Template marketplace
    - [ ] Multi-user support

- [ ] **Automated Container Provisioning Pipeline** (effort: L) - ⏳ SCRIPTS COMPLETE, ANSIBLE MIGRATION PENDING - Bash scripts for end-to-end automation complete (Mar 14). **Next:** Migrate all provisioning logic to Ansible playbooks and deprecate bash scripts. Components: auto-assign CTID, Netbox IPAM, NPM proxy, DNS, monitoring, backups. Scripts location: `scripts/provisioning/`. Target: Pure Ansible-based provisioning workflow.

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

- [x] **Semaphore Ansible Automation Platform** (effort: L) - ✅ COMPLETE (Mar 21) - Full automation platform with M365 SSO, self-updating templates, Teams notifications. 7 playbooks operational: Fix Python Modules, Health Check, PostgreSQL Status, Node.js App Restart, System Update, Sync Templates, Sync Inventory. Managing 29/30 hosts (29 containers + TrueNAS). Repository: github.com/heybearc/ansible-playbooks.

- [ ] **Container Renumbering Strategy** (effort: S) - ⏳ OPTIONAL - Migrating containers to correct CTID ranges. Completed: CT113→CT140 (adguard), CT118→CT141 (netbox). Remaining: CT121→CT142 (nginx-proxy). **Status:** Migration plan exists but not critical - CT121 works fine in current range. Method: Stop container, rename ZFS volume, rename config file, update rootfs reference, start container. Downtime: ~30 seconds.

- [ ] **Infrastructure-as-Code Templates** (effort: L) - Create Terraform/Ansible templates for container provisioning. Enables version-controlled infrastructure, repeatable deployments, disaster recovery.

- [ ] **Backup Automation for All Containers** (effort: M) - Automated backup procedures for all 28 containers. Schedule, retention policy, verification, restore testing. Reference: `documentation/BACKUP-IMPLEMENTATION-GUIDE.md`.

- [ ] **Enhanced VPN Killswitch** (effort: S) - SSH-preserving VPN killswitch for download clients. Prevents accidental exposure while maintaining management access.

### Low Priority

- [ ] **MSP Platform - Identity Provider Architecture** (effort: L) - Design hybrid SSO with Microsoft Entra ID (primary) + Authentik (fallback). Research Entra ID compatibility for each service, plan migration for NextAuth apps, document app registration process. Reference: `documentation/MSP-PLATFORM-ANALYSIS.md`.

- [ ] **MSP Platform - 3-Node Proxmox Cluster** (effort: XL) - Expand from single host to 3-node cluster for HA. Evaluate TrueNAS as second Proxmox node, design network topology, plan storage strategy (Ceph vs NFS), configure quorum and fencing. Target: 30-day timeline.

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

- [ ] Automated container provisioning pipeline (Scripts complete, Ansible migration pending)
- [x] Container naming convention standard (✅ Complete - 8 containers renamed)
- [x] Semaphore Ansible automation platform (✅ Complete - 7 playbooks, 29/30 hosts)
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

- [x] **TrueNAS OS Update** - ✅ COMPLETE (Mar 21) - Applied TrueNAS SCALE 25.04.2.6 (Fangtooth) update. Pool stable, no errors.

---

## ✅ Recently Completed (Last 30 Days)

### 2026-03-21
- [x] PostgreSQL High Availability automatic failover system deployed (Date: 2026-03-21)
- [x] Prometheus-based monitoring with 30-second failover detection (Date: 2026-03-21)
- [x] Webhook receiver on CT150 integrated with Semaphore API (Date: 2026-03-21)
- [x] Created PostgreSQL failover and recovery Ansible playbooks (Date: 2026-03-21)
- [x] Installed postgres_exporter on CT151 (standby replica) (Date: 2026-03-21)
- [x] Semaphore Ansible automation platform deployed with M365 SSO (Date: 2026-03-21)
- [x] Created 9 operational Ansible playbooks for infrastructure management (Date: 2026-03-21)
- [x] Self-updating template system - auto-creates Semaphore templates from playbooks (Date: 2026-03-21)
- [x] Teams notifications integrated with Semaphore task completion (Date: 2026-03-21)
- [x] Ansible connectivity established to 29/30 infrastructure hosts (Date: 2026-03-21)
- [x] Consolidated all tracking into IMPLEMENTATION-PLAN.md (removed BACKLOG.md, TASK-STATE.md archived) (Date: 2026-03-21)

### 2026-03-20
- [x] Scrypted NVR setup complete - 4 Nest cameras, 20TB NFS storage, motion detection (Date: 2026-03-20)
- [x] Fixed docker-compose.sh startup script to prevent configuration loss (Date: 2026-03-20)
- [x] Configured automated backups (Proxmox daily + database to TrueNAS) (Date: 2026-03-20)
- [x] Cost analysis: $50/year NVR license vs $156-300/year Ring+Nest subscriptions (Date: 2026-03-20)

### 2026-03-17
- [x] Cloudigan API - Stripe to Datto RMM webhook integration deployed (Date: 2026-03-17)
- [x] Auto-refresh OAuth token system (100-hour expiry, 1-hour safety buffer) (Date: 2026-03-17)
- [x] Wix CMS integration for customer download data storage (Date: 2026-03-17)

### 2026-03-16
- [x] Integrated Proxmox MCP server into Windsurf (Date: 2026-03-16)
- [x] Deployed CT180 (Scrypted NVR) using official Proxmox installer (Date: 2026-03-16)
- [x] Automation compliance: 7/8 components (87.5%) (Date: 2026-03-16)

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

**Last Updated:** 2026-03-21 (4:03 PM)  
**Maintained By:** Infrastructure Team  
**Status:** Active - Following control plane governance standards
