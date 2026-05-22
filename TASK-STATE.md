# Task State - homelab-nexus

**Last updated:** 2026-05-22 (end-day)

---

## Current Task
**Cloudigan Vault MSP** — **PAUSED** (infra done; commercial launch pending). **Or** resume other work (TIP Generator Phase 1, AIStor license rotation).

### What I'm doing right now
When returning to Vault: open `documentation/CLOUDIGAN-VAULT-PRODUCT.md` → public DNS + NPM SSL → Stripe tiers + Cloudigan API `product_type=vault` webhook → SMTP/white-label → Postgres/`DATA_FOLDER` replication.

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
- ✅ **Cloudigan Vault MSP infra** — CT171/172, HAProxy `vaultwarden_ha`, NPM 107, Ansible playbooks, Netbox; **D-HOMELAB-006** (new product, Cloudigan API billing)
- ✅ **Nextcloud** — verified healthy; NPM headers OK; no 429 lockouts
- ✅ **CT130 backups + Proxmox `local` cleanup** — single truenas-backups job; root **92% → 59%**
- ✅ **TrueNAS alerts** dismissed; stale ZJV425XP doc removed
- ✅ **Session docs** — `CLOUDIGAN-VAULT-PRODUCT.md`, `VAULTWARDEN-DEPLOYMENT.md`; mid-day commit `0a7d2e9`

### Recent completions (2026-05-07)
- ✅ **TrueNAS MinIO → AIStor** + Nextcloud back online. Details: `documentation/AISTOR-MIGRATION-2026-05-07.md`, D-HOMELAB-003.

_Older completions (Apr 2026): see `NOTES-ARCHIVE.md` or git history._

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

## Uncommitted work (end-day)

- **Ready to commit:** Ansible Vaultwarden playbooks/tasks, `.env.example`, Netbox scripts, `NOTES-ARCHIVE.md`
- **Intentionally uncommitted:** `files/Logos/`, `.cursor/`, unrelated `chapter-hub` playbooks (review separately)

## Exact Next Command

```bash
# Tomorrow — pick one:
open documentation/CLOUDIGAN-VAULT-PRODUCT.md   # Vault MSP (paused)
# curl -sS https://vault.cloudigan.com/alive   # after public DNS

# Or TIP Generator Phase 1:
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
