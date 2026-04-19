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

### ⏳ 3. Authentik OAuth Application - MANUAL REQUIRED

**Target:** CT170 (Authentik) - https://auth.cloudigan.net

**Create OAuth2/OIDC Provider:**
1. Navigate to Applications → Providers → Create
2. Provider type: OAuth2/OpenID Provider
3. Name: TIP Generator
4. Authorization flow: default-provider-authorization-implicit-consent
5. Client type: Confidential
6. Redirect URIs: 
   - `https://tip.cloudigan.net/auth/callback`
   - `http://10.92.3.90:8000/auth/callback` (BLUE direct)
   - `http://10.92.3.91:8000/auth/callback` (GREEN direct)
7. Scopes: openid, profile, email

**Create Application:**
1. Applications → Create
2. Name: TIP Generator
3. Slug: tip-generator
4. Provider: (select TIP Generator provider)
5. Launch URL: https://tip.cloudigan.net

**Save credentials for application:**
- Client ID: (generated)
- Client Secret: (generated)

### 4. Application Deployment

**Repository:** Create new repo `heybearc/tip-generator`

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
DATABASE_URL=postgresql://tip_user:PASSWORD@10.92.3.21:5432/tip_generator

# Authentik OAuth
AUTH_PROVIDER=authentik
AUTHENTIK_CLIENT_ID=...
AUTHENTIK_CLIENT_SECRET=...
AUTHENTIK_DOMAIN=auth.cloudigan.net
AUTHENTIK_REDIRECT_URI=https://tip.cloudigan.net/auth/callback

# Claude API
ANTHROPIC_API_KEY=sk-ant-...

# Application
STORAGE_PATH=/data/tip-generator
TEMPLATE_PATH=/data/tip-generator/templates/active-template.docx
SESSION_SECRET=...
ALLOWED_ORIGINS=https://tip.cloudigan.net
PORT=8000
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

### 6. MCP Server Integration

**Add to homelab-blue-green-mcp:**

```javascript
const apps = {
  // ... existing apps ...
  'tip-generator': {
    name: 'TIP Generator',
    blue: { host: '10.92.3.90', pm: 'tip-blue' },
    green: { host: '10.92.3.91', pm: 'tip-green' },
    port: 8000,
    healthPath: '/health',
    haproxyBackend: 'tip_backend'
  }
};
```

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
