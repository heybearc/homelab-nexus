# Task State - homelab-nexus

**Last updated:** 2026-04-22

---

## Current Task
**Authentik Branding & User Management** - COMPLETE ✅

### What I'm doing right now
Completed full Authentik branding for Cloudigan, invitation enrollment flow with group-based auto-assignment, and TIP Generator group access control. Ready to resume TIP Generator Phase 1 development.

### Recent completions (2026-04-22)
- ✅ **Authentik Branding - Cloudigan** (Apr 22)
  - SSH key deployed to CT170 via Proxmox exec (no password needed going forward)
  - API token created and saved to `.env` as `AUTHENTIK_API_TOKEN`
  - Cloudigan brand created at `auth.cloudigan.net` with color SVG logo + favicon
  - All flow titles changed from "Welcome to authentik!" → "Welcome to Cloudigan!"
  - CT170 SSH alias added to `~/.ssh/config` and `ssh_config_master.conf`
- ✅ **SSH Keys - Mass Deployment** (Apr 22)
  - Audited all containers for `homelab_root` key presence
  - Deployed missing keys to: CT121 (NPM), CT142, CT184, CT185, CT187
- ✅ **Authentik Invitation Enrollment Flow** (Apr 22)
  - Groups created: `cloudigan-admins`, `cloudigan-staff`, `cloudigan-clients`
  - Enrollment flow: `cloudigan-invitation-enrollment` (invite → username/email → password → auto-group → login)
  - Group assigned from invite `fixed_data.group` via expression policy
  - TIP Generator app: `cloudigan-admins` + `cloudigan-staff` groups bound (access control)
  - Invite link format: `https://auth.cloudigan.net/if/flow/cloudigan-invitation-enrollment/?itoken=<token>`

### Recent completions (2026-04-19)
- ✅ **TIP Generator - Complete Infrastructure Deployment** (Apr 19)
  - **Containers:** CT190 (tip-blue @ 10.92.3.90), CT191 (tip-green @ 10.92.3.91)
  - **HAProxy:** Blue-green backends configured on CT136/CT139 with health checks
  - **PostgreSQL:** Database `tip_generator` created on CT131 with user `tip_user`
  - **Authentik OAuth:** Provider and application configured with client credentials
  - **Backups:** Added to Tier 1 (daily at 2 AM, 7/4/3 retention) via vzdump.cron
  - **GitHub:** Repository created at https://github.com/heybearc/tip-generator
  - **MC Governance:** Cloudy-Work submodule integrated, .gitignore, .env.example
  - **Documentation:** ARCHITECTURE.md, DEPLOYMENT.md, DEVELOPMENT.md added
  - **MCP Integration:** Added to homelab-blue-green-mcp for automated deployments
  - **Resources:** 4GB RAM, 2 cores, 50GB disk per container
  - **Domain:** https://tip.cloudigan.net (via HAProxy VIP 10.92.3.33)

### Previous completions (2026-04-17)
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
1. **TIP Generator - Phase 1 Development** ← RESUME HERE
   - Clone repository: `git clone git@github.com:heybearc/tip-generator.git`
   - Set up backend: FastAPI with OAuth integration
   - Set up frontend: React with Vite
   - Implement template parser (Word document structure/styles)
   - Implement document upload (Excel, PDF)
   - Integrate Claude API for content generation
   - Deploy to STANDBY using MCP: `mcp0_deploy_to_standby tip-generator`
2. **TIP Generator - Gather Sample Documents** (for testing)
   - Provide example TIP Word template
   - Provide sample Excel discovery worksheet
   - Provide sample SOW/service order PDF
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

- **Authentik Embedded Outpost** shows "unhealthy" in UI — cosmetic only, WebSocket self-loopback issue in Docker. Does NOT affect auth/SSO. Fix: set `AUTHENTIK_HOST=http://10.92.3.75:9000` in `/opt/authentik/.env` (low priority)

---

## Exact Next Command

```bash
# Clone TIP Generator repository and begin Phase 1 development
cd /Users/cory/Projects
git clone git@github.com:heybearc/tip-generator.git
cd tip-generator

# Review documentation
open docs/DEVELOPMENT.md

# Set up backend
cd backend
python3.11 -m venv venv
source venv/bin/activate
# Create requirements.txt and begin FastAPI development
```

**Authentik Quick Reference (for future invites):**
- Create invite: Authentik UI → Directory → Invitations → Create → set `fixed_data: {"group": "cloudigan-staff"}`
- Or ask Cascade: "Create a staff invite for [name]"
- Groups: `cloudigan-admins`, `cloudigan-staff`, `cloudigan-clients`
- API token: `AUTHENTIK_API_TOKEN` in `.env`

---

## Infrastructure Summary

### Newly Deployed (2026-04-19)
| Service | Container | IP | Domain | Resources |
|---------|-----------|-----|--------|-----------|
| TIP Generator (BLUE) | CT190 | 10.92.3.90 | tip.cloudigan.net | 4GB RAM, 2 cores, 50GB disk |
| TIP Generator (GREEN) | CT191 | 10.92.3.91 | tip.cloudigan.net | 4GB RAM, 2 cores, 50GB disk |

### Previously Deployed (2026-04-08 - 2026-04-09)
| Service | Container | IP | Domain | Resources |
|---------|-----------|-----|--------|-----------|
| n8n | CT188 | 10.92.3.79 | flows.cloudigan.net | 4GB RAM, 2 cores |
| Vikunja | CT189 | 10.92.3.80 | tasks.cloudigan.net | 2GB RAM, 2 cores |
| LibreNMS | CT152 | 10.92.3.81 | netmon.cloudigan.net | 4GB RAM, 2 cores, 64GB disk |
| Uptime Kuma | CT153 | 10.92.3.82 | uptime.cloudigan.net | 1GB RAM, 1 core, 16GB disk |

### Total Resources (All Recent Deployments)
- **RAM:** 19GB
- **CPU Cores:** 13
- **Disk:** 180GB

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

**Pick up with:** Clone TIP Generator repository and begin Phase 1 development

**Key files:**
- `/Users/cory/Projects/tip-generator/` - TIP Generator repository (clone first)
- `/Users/cory/Projects/tip-generator/docs/DEVELOPMENT.md` - Development guide
- `/Users/cory/Projects/tip-generator/docs/DEPLOYMENT.md` - Deployment guide
- `/Users/cory/Projects/tip-generator/docs/ARCHITECTURE.md` - Full architecture plan
- `/Users/cory/Projects/homelab-nexus/documentation/TIP-GENERATOR-DEPLOYMENT.md` - Infrastructure details

**TIP Generator Infrastructure (Ready):**
- **Containers:** CT190 (BLUE @ 10.92.3.90), CT191 (GREEN @ 10.92.3.91)
- **Database:** `postgresql://tip_user:TipGen2026!Secure@10.92.3.21:5432/tip_generator`
- **OAuth:** Client ID and secret in docs/DEPLOYMENT.md
- **Domain:** https://tip.cloudigan.net (via HAProxy VIP 10.92.3.33)
- **GitHub:** https://github.com/heybearc/tip-generator
- **MCP Tools:** `mcp0_deploy_to_standby tip-generator`, `mcp0_switch_traffic tip-generator`

**Phase 1 Development Tasks:**
1. Set up FastAPI backend with OAuth integration
2. Set up React frontend with Vite
3. Implement Word template parser
4. Implement document upload (Excel, PDF)
5. Integrate Claude API for content generation
6. Deploy and test on STANDBY container

**Alternative Tasks:**
- Add network devices to LibreNMS (netmon.cloudigan.net)
- Configure n8n workflows (flows.cloudigan.net)
- Continue MSP Platform Phase 1 deployment

**Access credentials:**
- TIP Generator DB: tip_user / TipGen2026!Secure
- LibreNMS: admin / Cloudigan2026!
- Vikunja: cory@cloudigan.com (admin)
- Grafana: admin / Cloudy_92!
- NPM: admin@cloudigan.com / HlZDa2@rd*mivNrl5kqQ
