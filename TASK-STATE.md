# Task State - homelab-nexus

**Last updated:** 2026-05-16 (mid-day)

---

## Current Task
**PAUSED** — handling another task. **Resume Cloudigan Vault** from `documentation/CLOUDIGAN-VAULT-PRODUCT.md`.

### What I'm doing right now
Vault MSP infra is largely done (see **Paused: Cloudigan Vault MSP** below). When resuming: DNS + NPM SSL → branding/SMTP → Stripe products → Cloudigan API vault webhook branch → DB/data replication.

### Paused: Cloudigan Vault MSP (2026-05-16 session)

**Full notes:** [`documentation/CLOUDIGAN-VAULT-PRODUCT.md`](documentation/CLOUDIGAN-VAULT-PRODUCT.md)

| Topic | Decision / state |
|-------|------------------|
| **Product** | New paid MSP on `vault.cloudigan.com` — **not** homelab TrueNAS cutover |
| **Infra** | CT171 BLUE active, CT172 GREEN staged (not running); HAProxy + NPM 107 |
| **Billing** | Stripe → **Cloudigan API** (extend D-038); **not** n8n for checkout |
| **Pricing** | Proposed Starter / Business / Business Plus — **not in Stripe yet** (see product doc) |
| **White label** | SMTP, templates, `DOMAIN`, org invites; Bitwarden apps unchanged |
| **DNS** | Manual A → `174.104.207.3` (Wix MCP lacks DNS permissions) |
| **Next** | DNS/SSL verify → Stripe + API vault branch → SMTP/branding → replication runbook |

### Recent completions (2026-05-16)
- ✅ **Vaultwarden LXC pair (CT171/172)** — BLUE active @ `10.92.3.94`, GREEN standby staged @ `.95` (compose + image, not running); Netbox IPs; privileged LXC for Docker
- ✅ **HAProxy `vaultwarden_ha`** — primary **BLUE** `.94`, backup **GREEN** `.95` (TrueNAS excluded — separate homelab instance)
- ✅ **NPM proxy host 107** — `vault.cloudigan.com` → `10.92.3.33:80` (SSL cert ID 96; confirm after public DNS)
- ✅ **Nextcloud (`nextcloud.cloudigan.net`)** — verified healthy: `status.php` 200 (v33.0.3.2, not in maintenance); desktop sync (Windows + Mac clients) and web UI returning 200; **0** HTTP 429 in NPM access log; NPM proxy host 46 forwards `X-Forwarded-*` via standard `proxy.conf` include. Residual NPM `trust_forwarded_proto` nginx warnings are cosmetic (do not block sync). See D-HOMELAB-003 / AISTOR migration notes.
- ✅ **CT130 (BookStack) backups** — removed `storage local` job + duplicate job; single daily → `truenas-backups` with prune `keep-daily=7,keep-weekly=4,keep-monthly=3`
- ✅ **Proxmox `local` cleanup** — deleted ~30G stale vzdump on root (`92%` → `59%`); ISOs still ~36G if more space needed
- ✅ **TrueNAS alerts** — dismissed app-update INFO alerts (nextcloud, vaultwarden, aistor); pool healthy
- ✅ **Docs** — removed stale ZJV425XP disk alert from `documentation/proxmox-infrastructure-spec.md`

### Recent completions (2026-05-12)
- ✅ **Proxmox (`prox`) Tailscale** — upgraded **1.86.2 → 1.96.4**; **`tailscale set --accept-dns=false`** because `/etc/resolv.conf` is **immutable** (`chattr +i`); subnet routes for `10.92.0.0/23`–`10.92.5.0/24` remain advertised; health warnings cleared.
- ✅ **cloudy-renvis01 RDP TLS** — repo scripts: `scripts/windows/rdp-listener-custom-cert.ps1` (self-signed SANs for **`cloudy-renvis01.cloudigan.com`**, MagicDNS, NetBIOS, Tailscale + LAN IPs; WMI bind + optional `TermService` restart); `scripts/windows/import-rdp-listener-trust-cert.ps1` (trust `C:\temp\rdp-listener-homelab.cer` on Windows clients).
- ✅ **Vaultwarden MSP / redundancy** — agreed architecture: **`vault.cloudigan.com`** via NPM; **HAProxy `server` + `backup`** with **`/alive`** checks; avoid active/active dual Vaultwarden writers; white label via `DOMAIN`, SMTP, templates, vault web assets.

### Recent completions (2026-05-07)
- ✅ **TrueNAS MinIO → AIStor** + Nextcloud back online. Details: `documentation/AISTOR-MIGRATION-2026-05-07.md`, D-HOMELAB-003.

### Previous completions (2026-04-22)
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
1. **AIStor: rotate license + verify** (paranoia — license JWT was pasted in chat)
   - Re-download from https://subnet.min.io
   - Update via TrueNAS UI Apps → aistor → Edit, or via `midclt app.update aistor` with new `aistor.license_key`
   - Confirm with `mc license info` from a host with `mc` configured
2. **AIStor: post-migration verification** (week-long)
   - Daily Nextcloud usage smoke test (upload/download/preview)
   - Once stable for 7 days, drop `pre-aistor-20260507` snapshots to reclaim space
3. **TIP Generator - Phase 1 Development** ← RESUME HERE (was deferred for AIStor migration)
   - Clone repository: `git clone git@github.com:heybearc/tip-generator.git`
   - Set up backend: FastAPI with OAuth integration
   - Set up frontend: React with Vite
   - Implement template parser (Word document structure/styles)
   - Implement document upload (Excel, PDF)
   - Integrate Claude API for content generation
   - Deploy to STANDBY using MCP: `mcp0_deploy_to_standby tip-generator`
4. **TIP Generator - Gather Sample Documents** (for testing)
   - Provide example TIP Word template
   - Provide sample Excel discovery worksheet
   - Provide sample SOW/service order PDF
5. **Vaultwarden MSP — `vault.cloudigan.com`** ← **PAUSED** (see `documentation/CLOUDIGAN-VAULT-PRODUCT.md`)
   - See **Vaultwarden HA plan** section below
6. **MSP Platform - Continue Phase 1 deployment**
   - BookStack (documentation hub)
   - Plane (project management)
   - Authentik/Entra ID SSO research
7. **LibreNMS - Add network devices**
   - Switches, APs, Omada Controller
   - Enable auto-discovery
   - Configure SNMP communities
8. **n8n - Configure first workflows**
   - Set up automation workflows
   - Integrate with 1Password
   - Connect to MSP services

---

## Vaultwarden HA plan (D-HOMELAB-004)

**Goal:** Survive single-node outage (TrueNAS app down OR standby LXC down) with automatic failover, no dual writers.

| Phase | Work | Outcome |
|-------|------|---------|
| **0** | `vault.cloudigan.com` DNS → NPM → HAProxy VIP `10.92.3.33` | NPM + HAProxy done; **public DNS manual** |
| **1** | Postgres DB `vaultwarden` on CT131; replicate to CT151 | DB on CT131 ✅; replica pending |
| **2** | Ansible `deploy-vaultwarden-containers.yml` → CT171/172 on `vmbr0923` | **Done** — GREEN staged, not started |
| **3** | Sync `DATA_FOLDER` (ZFS snapshot/replication or `rsync` + orchestration) | Attachments/icons survive failover |
| **4** | HAProxy: primary BLUE, `backup` GREEN, `GET /alive` | **Done** (MSP pool; TrueNAS excluded) |
| **5** | Runbook: promote standby DB + start Vaultwarden + validate Bitwarden clients | Documented RPO/RTO |

**Not in scope:** active/active Vaultwarden (forbidden per D-HOMELAB-004).

**Optional:** use spare 12TB (`sdk`) as dedicated dataset for vault data/backups (separate from `media-pool` stripe).

---

## Known Issues

- **Authentik Embedded Outpost** shows "unhealthy" in UI — cosmetic only, WebSocket self-loopback issue in Docker. Does NOT affect auth/SSO. Fix: set `AUTHENTIK_HOST=http://10.92.3.75:9000` in `/opt/authentik/.env` (low priority)
- **NPM `trust_forwarded_proto` warnings** on proxy host 46 — cosmetic nginx/NPM log noise; Nextcloud verified working 2026-05-16 (no 429 lockouts, sync active). Optional: add Nextcloud advanced NPM config to silence warnings.
- **AIStor Free-tier license JWT was pasted in agent chat** — rotate via SUBNET to be safe.

---

## Exact Next Command

```bash
# Resume Cloudigan Vault (product + infra):
open documentation/CLOUDIGAN-VAULT-PRODUCT.md
# After public DNS:
curl -sS https://vault.cloudigan.com/alive

# Or resume TIP Generator Phase 1:
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

**Pick up with:** Vaultwarden HA buildout (primary task) or TIP Generator Phase 1 clone/dev.

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
