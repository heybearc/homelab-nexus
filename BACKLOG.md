# Homelab Infrastructure Backlog

**Last Updated:** 2026-03-21

---

## 🔴 High Priority

### PostgreSQL High Availability Setup
**Status:** Discovered - Not Implemented  
**Discovery Date:** 2026-03-21  
**Current State:**
- Single PostgreSQL server (CT131 - postgresql-primary)
- No replication configured
- CT132 (postgresql-replica) exists but has no PostgreSQL installed

**Target State:**
- Primary-replica replication between CT131 and CT132
- Automatic failover capability
- Read scaling from replica

**Implementation Steps:**
1. Install PostgreSQL 17 on CT132
2. Configure streaming replication from CT131 to CT132
3. Set up automatic failover with Patroni or repmgr
4. Update Ansible playbooks to monitor both servers
5. Test failover scenarios

**Estimated Effort:** 4-6 hours  
**Dependencies:** None  
**Priority Justification:** Currently single point of failure for all MSP platform databases

---

## 🟡 Medium Priority

### Backup Coverage Completion
**Status:** In Progress  
**Reference:** `documentation/BACKUP-IMPLEMENTATION-GUIDE.md`  
**Current:** 1/28 containers backed up  
**Target:** 28/28 containers with tiered backup strategy

### Container Monitoring Enhancement
**Status:** Planned  
**Current:** Basic health checks via Ansible  
**Target:** Comprehensive monitoring with Prometheus/Grafana

---

## 🟢 Low Priority

### Additional Ansible Playbooks
**Status:** Backlog  
**Ideas:**
- Certificate renewal automation
- Log rotation and cleanup
- Security patching workflow
- Container resource optimization
- Network connectivity tests

### Documentation Improvements
**Status:** Ongoing  
**Items:**
- Network topology diagrams
- Service dependency maps
- Disaster recovery procedures
- Runbook for common issues

---

## ✅ Completed

### Semaphore Automation Platform (2026-03-21)
- ✅ Microsoft 365 SSO integration
- ✅ Ansible playbook repository created
- ✅ Self-updating template system
- ✅ Teams notifications
- ✅ 6 operational playbooks
- ✅ 13/20 hosts reachable via Ansible

---

## 📝 Notes

**Naming Convention Request:** 
- User requested renaming "implementation plan" to just "plan" for easier typing
- Consider updating control plane terminology

**Infrastructure Overview:**
- 28 LXC containers across Proxmox cluster
- 6 Node.js applications (blue/green deployments)
- 1 PostgreSQL server (needs HA)
- HAProxy load balancing
- TrueNAS for storage (20TB available)
