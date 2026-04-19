# TIP Generator Deployment Status

**Date:** 2026-04-19  
**Status:** Infrastructure Deployed ✅  
**Next Phase:** Application Setup

---

## Deployed Infrastructure

### Blue-Green Containers

**BLUE Node (CT190)**
- **Hostname:** tip-blue
- **IP Address:** 10.92.3.90
- **Resources:** 4GB RAM, 2 cores, 50GB disk
- **Status:** ✅ Running
- **Path:** /opt/tip-generator (to be created)
- **Access:** `ssh root@10.92.3.90`

**GREEN Node (CT191)**
- **Hostname:** tip-green
- **IP Address:** 10.92.3.91
- **Resources:** 4GB RAM, 2 cores, 50GB disk
- **Status:** ✅ Running
- **Path:** /opt/tip-generator (to be created)
- **Access:** `ssh root@10.92.3.91`

### Automation Completed

✅ **Netbox Registration**
- Both containers registered in IPAM
- CTID: 190, 191
- Function: dev

✅ **NPM Reverse Proxy**
- Domain: tip.cloudigan.net
- Proxy created and configured
- Forwards to: 10.92.3.90:8000 (will update to HAProxy VIP)

✅ **Internal DNS**
- tip-blue.cloudigan.net → 10.92.3.90
- tip-green.cloudigan.net → 10.92.3.91
- tip.cloudigan.net → 10.92.3.3 (NPM)

✅ **Monitoring**
- node_exporter installed (port 9100)
- promtail installed (log shipping to Loki)
- Ready for Prometheus scraping

✅ **Backups** - **TIER 1 CRITICAL**
- Added to `/etc/pve/vzdump.cron` Tier 1 (Critical Production)
- Schedule: Daily at 2:00 AM
- Storage: truenas-backups (TrueNAS NFS)
- Compression: zstd
- Mode: snapshot
- Retention: keep-daily=7, keep-weekly=4, keep-monthly=3
- Email notifications on failure
- **Note:** Ansible playbook updated to use vzdump.cron instead of deprecated pvesh method

---

## Configuration Progress

### ✅ 1. HAProxy Backend Configuration - COMPLETE

**Target:** CT136 (MASTER) and CT139 (BACKUP) - **COMPLETED 2026-04-19**

Add to `/etc/haproxy/haproxy.cfg`:

```haproxy
# TIP Generator Backend
backend tip_backend
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server tip-blue 10.92.3.90:8000 check
    server tip-green 10.92.3.91:8000 check backup

# TIP Generator Frontend ACL
frontend https_frontend
    # ... existing config ...
    acl is_tip hdr(host) -i tip.cloudigan.net
    use_backend tip_backend if is_tip
```

**Update NPM to forward to HAProxy VIP:**
- Change forward_host from 10.92.3.90 to 10.92.3.33
- Keep forward_port as 8000

**Status:** ✅ Configured on both HAProxy nodes
- ACLs added for tip.cloudigan.net, blue-tip.cloudigan.net, green-tip.cloudigan.net
- Backend `tip_blue` routes to 10.92.3.90:8000
- Backend `tip_green` routes to 10.92.3.91:8000
- Health check: GET /health (expects 200)
- Configuration validated and reloaded on both CT136 and CT139

### ✅ 2. PostgreSQL Database Setup - COMPLETE

**Target:** CT131 (PostgreSQL primary) - **COMPLETED 2026-04-19**

```sql
-- Create database and user
CREATE DATABASE tip_generator;
CREATE USER tip_user WITH ENCRYPTED PASSWORD 'TIP_PASSWORD_HERE';
GRANT ALL PRIVILEGES ON DATABASE tip_generator TO tip_user;

-- Connect to database and grant schema permissions
\c tip_generator
GRANT ALL ON SCHEMA public TO tip_user;
ALTER DATABASE tip_generator OWNER TO tip_user;
```

**Status:** ✅ Database created and configured
- Database: `tip_generator`
- User: `tip_user`
- Password: `TipGen2026!Secure`
- All privileges granted
- Schema ownership transferred

**Connection String:**
```
postgresql://tip_user:TipGen2026!Secure@10.92.3.21:5432/tip_generator
```

### ✅ 3. Authentik OAuth Application - COMPLETE

**Target:** CT170 (Authentik) - https://auth.cloudigan.net - **COMPLETED 2026-04-19**

**OAuth2/OIDC Provider Created:**
- Provider ID: 4
- Name: TIP Generator
- Client Type: Confidential
- Authorization Flow: default-provider-authorization-implicit-consent
- Redirect URIs: 
  - `https://tip.cloudigan.net/auth/callback` (production)
  - `http://10.92.3.90:8000/auth/callback` (BLUE direct)
  - `http://10.92.3.91:8000/auth/callback` (GREEN direct)
- Sub Mode: hashed_user_id
- Include Claims in ID Token: Yes
- Issuer Mode: per_provider

**Application Created:**
- Application ID: f1e56917-7cca-4b00-8e06-d6225815b56f
- Name: TIP Generator
- Slug: tip-generator
- Launch URL: https://tip.cloudigan.net
- Open in New Tab: Yes

**OAuth Credentials:**
- **Client ID:** `MFO9C9ynlvpoX895YRSutwCl7xBouyAy4oOjNmI9`
- **Client Secret:** `tfCdQRgZHcIeE1bMCpioR2Beb1p3PuwmnZcPNZZqc3JGdAHRCXG4F0rk3ndP6nrGKJMF9lY92GW0gOW2i6laGMwXEfmdOIHtzWXWJWmEeBUeDOTzFaspAPSo03nVTA5A`
- **Issuer URL:** `https://auth.cloudigan.net/application/o/tip-generator/`
- **Token Validity:** Access: 1 hour, Refresh: 30 days

### ✅ 4. GitHub Repository - COMPLETE

**Repository:** https://github.com/heybearc/tip-generator - **CREATED 2026-04-19**

**Initial Setup:**
- ✅ Repository created (public)
- ✅ README.md with architecture and deployment info
- ✅ .gitignore following MC governance standards
- ✅ .env.example with all required variables
- ✅ Project structure: backend/, frontend/, docs/
- ✅ Master Control (Cloudy-Work) submodule integrated
- ✅ Repository fully MC-managed with governance and policies
- ✅ Initial commits pushed to main branch

**Local Clone:**
```bash
git clone git@github.com:heybearc/tip-generator.git
cd tip-generator
```

### 5. Application Deployment (Phase 1 - In Progress)

**Tech Stack:**
- Backend: FastAPI (Python 3.11+)
- Frontend: React (Vite build)
- Database: PostgreSQL (via SQLAlchemy)
- Auth: FastAPI OAuth with Authentik
- AI: Claude API (Anthropic)
- Document Processing: python-docx, openpyxl, PyMuPDF

**Environment Variables (.env):**
```bash
# Database
DATABASE_URL=postgresql://tip_user:TipGen2026!Secure@10.92.3.21:5432/tip_generator

# Authentik OAuth
AUTH_PROVIDER=authentik
AUTHENTIK_CLIENT_ID=MFO9C9ynlvpoX895YRSutwCl7xBouyAy4oOjNmI9
AUTHENTIK_CLIENT_SECRET=tfCdQRgZHcIeE1bMCpioR2Beb1p3PuwmnZcPNZZqc3JGdAHRCXG4F0rk3ndP6nrGKJMF9lY92GW0gOW2i6laGMwXEfmdOIHtzWXWJWmEeBUeDOTzFaspAPSo03nVTA5A
AUTHENTIK_DOMAIN=auth.cloudigan.net
AUTHENTIK_ISSUER=https://auth.cloudigan.net/application/o/tip-generator/
AUTHENTIK_REDIRECT_URI=https://tip.cloudigan.net/auth/callback

# Claude API
ANTHROPIC_API_KEY=sk-ant-... # To be added during Phase 1 development

# Application
STORAGE_PATH=/data/tip-generator
TEMPLATE_PATH=/data/tip-generator/templates/active-template.docx
SESSION_SECRET=... # Generate random secret during deployment
ALLOWED_ORIGINS=https://tip.cloudigan.net
PORT=8000
NODE_ENV=production
```

**Directory Structure:**
```
/opt/tip-generator/
├── backend/          # FastAPI application
├── frontend/         # React application
├── .env             # Environment variables
└── /data/tip-generator/
    ├── templates/
    │   └── active-template.docx
    ├── projects/
    │   └── {project_id}/
    └── cache/
```

### 5. Wix DNS Configuration

**Manual Step Required:**

Login to Wix DNS management and create CNAME:
- **Subdomain:** tip
- **Points to:** cloudigan.net
- **TTL:** Auto

This will make `tip.cloudigan.net` resolve through Cloudflare → NPM → HAProxy → TIP containers.

### ✅ 6. MCP Server Integration - COMPLETE

**Added to homelab-blue-green-mcp:** - **COMPLETED 2026-04-19**

**Configuration:**
```javascript
'tip-generator': {
  name: 'TIP Generator',
  blueIp: '10.92.3.90',
  greenIp: '10.92.3.91',
  blueContainer: 190,
  greenContainer: 191,
  haproxyBackend: 'tip',
  sshBlue: 'root@10.92.3.90',
  sshGreen: 'root@10.92.3.91',
  path: '/opt/tip-generator',
  branch: 'main',
  pmBlue: 'tip-generator',
  pmGreen: 'tip-generator',
  healthEndpoint: '/health',
  port: 8000,
}
```

**Available MCP Tools:**
- `mcp0_get_deployment_status` - Check LIVE/STANDBY status
- `mcp0_deploy_to_standby` - Deploy to STANDBY container
- `mcp0_switch_traffic` - Switch HAProxy traffic (LIVE ↔ STANDBY)

---

## Next Steps

1. **Configure HAProxy** - Add backend and frontend ACL
2. **Create PostgreSQL database** - Run SQL commands on CT131
3. **Set up Authentik OAuth** - Create provider and application
4. **Create GitHub repository** - Initialize tip-generator repo
5. **Deploy Phase 1 application** - FastAPI backend + React frontend
6. **Configure Wix DNS** - Add CNAME record
7. **Test end-to-end** - Upload → Generate → Export workflow

---

## Architecture Reference

**Plan:** `~/.windsurf/plans/tip-generator-webapp-424e2d.md`  
**Decisions:** D-036 (phased rollout), D-037 (template management)  
**Deployment Pattern:** Blue-green with HAProxy VIP (10.92.3.33)  
**Monitoring:** Prometheus + Grafana + Uptime Kuma  
**Backups:** Critical priority (daily Proxmox snapshots + PostgreSQL HA)

---

**Deployment completed:** 2026-04-19 08:31 AM  
**Deployed by:** Ansible automation (deploy-proxmox-container.yml)  
**Infrastructure status:** ✅ Ready for application deployment
