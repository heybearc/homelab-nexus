# Task State - homelab-nexus

**Last updated:** 2026-04-17

---

## Current Task
**TIP Generator Web Application - Planning & Architecture** - PLANNING COMPLETE

### What I'm doing right now
Completed comprehensive planning for AI-powered Technical Implementation Plan (TIP) generator web application. Designed phased rollout: v1 single-user with template intelligence, v2 team collaboration with blue-green deployment.

### Recent completions (2026-04-17)
- ✅ **TIP Generator Web Application - Planning** (Apr 17)
  - Comprehensive architecture plan created
  - Phased rollout strategy: v1 single-user → v2 team collaboration
  - Template intelligence: auto-detect structure, styles, colors from Word template
  - AI-powered content generation with Claude API
  - React + FastAPI stack with PostgreSQL
  - Authentik/M365 OAuth authentication
  - Blue-green deployment ready for v2
  - Plan saved: `~/.windsurf/plans/tip-generator-webapp-424e2d.md`

### Previous completions (2026-04-08 - 2026-04-09)
- ✅ **n8n Workflow Automation** (CT188 @ 10.92.3.79) - flows.cloudigan.net
  - Docker deployment with PostgreSQL backend (cloudigan_n8n)
  - NPM reverse proxy with SSL
  - 4GB RAM, 2 cores
- ✅ **Vikunja Task Management** (CT189 @ 10.92.3.80) - tasks.cloudigan.net
  - Docker deployment with PostgreSQL backend (cloudigan_vikunja)
  - Admin user: cory@cloudigan.com (first user = auto-admin)
  - 2GB RAM, 2 cores
- ✅ **LibreNMS Network Monitoring** (CT152 @ 10.92.3.81) - netmon.cloudigan.net
  - Docker Compose deployment (LibreNMS + MariaDB + Redis + Dispatcher + Syslog)
  - Admin user: admin / Cloudigan2026!
  - ER7206 Gateway (10.92.3.1) added as first device
  - MySQL database exposed on port 3306 for Grafana integration
  - 4GB RAM, 2 cores, 64GB disk
- ✅ **Uptime Kuma Monitoring** (CT153 @ 10.92.3.82) - uptime.cloudigan.net
  - Upgraded from v1.23.16 → v2.2.1
  - Migrated 28 active monitors from CT150 to CT153
  - 310MB database with historical data preserved
  - All production services monitored (QuantShift, TheoShift, LDC Tools, databases, HAProxy, containers)
  - 1GB RAM, 1 core, 16GB disk
- ✅ **Grafana + LibreNMS Integration**
  - LibreNMS MySQL datasource configured in Grafana
  - Created 2 English dashboards (removed Chinese ones):
    - "LibreNMS - Device Status" (device counts, inventory table)
    - "LibreNMS Network Overview" (basic metrics)
  - Prometheus integration (LibreNMS exporter on port 9100)
  - LibreNMS added to Prometheus scrape config
- ✅ **SSH Key Deployment**
  - Deployed SSH keys to all new containers (CT188, CT189, CT152, CT153)
  - Root access configured for management
- ✅ **Decommissioned Documenso** (CT188 reused)
  - Removed Netbox entry
  - Container repurposed for n8n

### Next steps
1. **TIP Generator - Gather Sample Documents**
   - Provide example TIP Word template
   - Provide sample Excel discovery worksheet
   - Provide sample SOW/service order PDF
   - Review plan and confirm architecture
2. **TIP Generator - Phase 1 Implementation** (if approved)
   - Set up project structure (React + FastAPI)
   - Develop Word template parser (structure, styles, colors)
   - Database schema and models
   - File upload system
   - Authentik OAuth integration
3. **MSP Platform - Continue Phase 1 deployment**
   - BookStack (documentation hub)
   - Plane (project management)
   - Authentik/Entra ID SSO research
4. **LibreNMS - Add network devices**
   - Switches, APs, Omada Controller
   - Enable auto-discovery
   - Configure SNMP communities
5. **n8n - Configure first workflows**
   - Set up automation workflows
   - Integrate with 1Password
   - Connect to MSP services

---

## Known Issues

**None** - All deployments successful and operational

---

## Exact Next Command

```bash
# Review TIP Generator plan and gather sample documents
open ~/.windsurf/plans/tip-generator-webapp-424e2d.md

# Once approved, start Phase 1 implementation:
# 1. Create project directory structure
# 2. Set up React + FastAPI boilerplate
# 3. Begin Word template parser development
```

---

## Infrastructure Summary

### Newly Deployed (Today)
| Service | Container | IP | Domain | Resources |
|---------|-----------|-----|--------|-----------|
| n8n | CT188 | 10.92.3.79 | flows.cloudigan.net | 4GB RAM, 2 cores |
| Vikunja | CT189 | 10.92.3.80 | tasks.cloudigan.net | 2GB RAM, 2 cores |
| LibreNMS | CT152 | 10.92.3.81 | netmon.cloudigan.net | 4GB RAM, 2 cores, 64GB disk |
| Uptime Kuma | CT153 | 10.92.3.82 | uptime.cloudigan.net | 1GB RAM, 1 core, 16GB disk |

### Total New Resources
- **RAM:** 11GB
- **CPU Cores:** 9
- **Disk:** 80GB

### Monitoring Coverage
- **Uptime Kuma:** 28 active monitors (all production services)
- **LibreNMS:** 1 device (ER7206 Gateway)
- **Prometheus:** LibreNMS metrics integrated
- **Grafana:** 2 LibreNMS dashboards

---

## Notes

- All services deployed using Ansible playbook: `deploy-proxmox-container.yml`
- All containers registered in Netbox
- All domains configured in NPM with SSL
- All services integrated with existing monitoring stack (Prometheus/Grafana on CT150)
- Uptime Kuma migration preserved all historical data and monitor configurations
- LibreNMS ready for network device discovery and topology mapping
- n8n and Vikunja ready for workflow/project configuration

---

## Context for Tomorrow

**Pick up with:** Review TIP Generator plan, gather sample documents, or begin implementation

**Key files:**
- `~/.windsurf/plans/tip-generator-webapp-424e2d.md` - TIP Generator comprehensive plan
- `/Users/cory/Projects/homelab-nexus/IMPLEMENTATION-PLAN.md` - MSP platform roadmap
- `/Users/cory/Projects/homelab-nexus/TASK-STATE.md` - Current task state

**TIP Generator Next Actions:**
1. Review plan with stakeholders
2. Gather sample documents (Word template, Excel worksheet, SOW PDF)
3. Confirm architecture and feature set
4. Begin Phase 1 implementation if approved

**Alternative Tasks (if waiting on TIP approval):**
- Add network devices to LibreNMS (netmon.cloudigan.net)
- Configure n8n workflows (flows.cloudigan.net)
- Continue MSP Platform Phase 1 deployment

**Access credentials:**
- LibreNMS: admin / Cloudigan2026!
- Vikunja: cory@cloudigan.com (admin)
- Grafana: admin / Cloudy_92!
- NPM: admin@cloudigan.com / HlZDa2@rd*mivNrl5kqQ
