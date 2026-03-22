# MSP Platform - Phase 1 Deployment Plan

**Date:** 2026-03-21  
**Status:** Ready to Deploy  
**Timeline:** 1-2 weeks

---

## Executive Summary

**Phase 1 Goal:** Deploy foundational MSP platform services (Identity, Documentation Hub, Project Management)

**Services to Deploy:**
1. **Authentik** - SSO Identity Provider (CT175)
2. **BookStack Blue** - Documentation Hub (CT201)
3. **BookStack Green** - Documentation Hub Standby (CT202)
4. **Ansible Control** - Infrastructure automation (CT183) ✅ **DEPLOYED**

**Prerequisites:**
- ✅ Proxmox backups complete (28/28 containers)
- ✅ PostgreSQL cluster ready (will upgrade during deployment)
- ✅ Network infrastructure documented
- ✅ SSO architecture designed
- ✅ Ansible control node deployed (CT183)

---

## Deployment Order

### Step 1: Upgrade PostgreSQL Cluster ⏳
**Timeline:** 2-3 hours  
**When:** Before deploying MSP services  
**Why:** MSP services need upgraded database capacity

**Procedure:** Follow `POSTGRESQL-REPLICA-FIRST-UPGRADE.md`

**Key Points:**
- Zero-downtime upgrade using replica-first promotion
- Blue-green application restart flow for TheoShift/LDC Tools/QuantShift
- Upgrade resources: 8GB RAM, 100GB storage, 250 max connections

**Verification:**
```bash
# Check upgraded resources
ssh prox "pct config 151 | grep -E 'cores|memory|rootfs'"
ssh prox "pct config 131 | grep -E 'cores|memory|rootfs'"

# Verify replication
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"
```

---

### Step 2: Deploy Authentik (SSO) ⏳
**Container:** CT175  
**Timeline:** 2-3 hours  
**Dependencies:** PostgreSQL cluster upgraded

**Specifications:**
- **Name:** authentik
- **Function:** security (CTID range 170-179)
- **IP:** 10.92.3.75
- **Domain:** auth.cloudigan.net
- **Resources:** 4GB RAM, 2 cores, 32GB disk
- **SSL:** Yes

**Deployment Command:**
```bash
# Using Proxmox MCP
mcp1_create_container(
  name="authentik",
  function="security",
  ip="10.92.3.75",
  cores=2,
  memory=4096,
  disk=32,
  domain="auth.cloudigan.net",
  port=9000,
  ssl=true
)
```

**Post-Deployment:**
1. Install Docker and Docker Compose (Authentik requires Docker)
2. Create PostgreSQL database: `cloudigan_authentik`
3. Configure Authentik with Docker Compose
4. Set up Entra ID federation
5. Create initial admin user
6. Configure email notifications

**Configuration:**
```yaml
# docker-compose.yml
version: '3.8'
services:
  authentik-server:
    image: ghcr.io/goauthentik/server:latest
    environment:
      AUTHENTIK_SECRET_KEY: <generate-secret>
      AUTHENTIK_POSTGRESQL__HOST: 10.92.3.32
      AUTHENTIK_POSTGRESQL__NAME: cloudigan_authentik
      AUTHENTIK_POSTGRESQL__USER: authentik_user
      AUTHENTIK_POSTGRESQL__PASSWORD: <from-1password>
      AUTHENTIK_REDIS__HOST: localhost
    ports:
      - "9000:9000"
      - "9443:9443"
  
  authentik-worker:
    image: ghcr.io/goauthentik/server:latest
    command: worker
    environment:
      # Same as server
  
  redis:
    image: redis:alpine
```

**Entra ID Federation:**
1. Create OIDC source in Authentik
2. Configure Entra ID as upstream provider
3. Map user attributes (email, name, groups)
4. Test authentication flow

---

### Step 3: Deploy BookStack Blue ⏳
**Container:** CT201  
**Timeline:** 1-2 hours  
**Dependencies:** PostgreSQL cluster, Authentik deployed

**Specifications:**
- **Name:** bookstack-blue
- **Function:** utility (CTID range 180-189)
- **IP:** 10.92.3.101
- **Domain:** docs.cloudigan.net (will point to HAProxy VIP)
- **Resources:** 2GB RAM, 2 cores, 32GB disk
- **SSL:** Yes (via NPM)

**Deployment Command:**
```bash
# Using Proxmox MCP
mcp1_create_container(
  name="bookstack-blue",
  function="utility",
  ip="10.92.3.101",
  cores=2,
  memory=2048,
  disk=32,
  domain="bookstack-blue.cloudigan.net",
  port=80,
  ssl=true
)
```

**Post-Deployment:**
1. Install Nginx, PHP 8.1, Composer
2. Clone BookStack from GitHub
3. Create PostgreSQL database: `cloudigan_bookstack`
4. Configure `.env` file
5. Run migrations
6. Configure OIDC with Authentik
7. Create initial admin user
8. Import documentation structure

**OIDC Configuration:**
```env
# .env
AUTH_METHOD=oidc
OIDC_NAME=Cloudigan SSO
OIDC_DISPLAY_NAME_CLAIMS=name
OIDC_CLIENT_ID=<from-authentik>
OIDC_CLIENT_SECRET=<from-authentik>
OIDC_ISSUER=https://auth.cloudigan.net/application/o/bookstack/
OIDC_ISSUER_DISCOVER=true
```

---

### Step 4: Deploy BookStack Green ⏳
**Container:** CT202  
**Timeline:** 1 hour  
**Dependencies:** BookStack Blue deployed and tested

**Specifications:**
- **Name:** bookstack-green
- **Function:** utility
- **IP:** 10.92.3.102
- **Domain:** bookstack-green.cloudigan.net
- **Resources:** 2GB RAM, 2 cores, 32GB disk
- **SSL:** Yes

**Deployment:**
- Clone BookStack Blue configuration
- Point to same PostgreSQL database
- Test independently
- Add to HAProxy backend

---

### Step 5: Configure HAProxy for BookStack ⏳
**Timeline:** 30 minutes  
**Dependencies:** Both BookStack containers deployed

**HAProxy Configuration:**
```bash
# Add to /etc/haproxy/haproxy.cfg on CT136

backend bookstack
    mode http
    balance roundrobin
    option httpchk GET /login
    http-check expect status 200
    
    server bookstack-blue 10.92.3.101:80 check
    server bookstack-green 10.92.3.102:80 check backup

frontend https_front
    # Add BookStack to existing frontend
    acl is_bookstack hdr(host) -i docs.cloudigan.net
    use_backend bookstack if is_bookstack
```

**NPM Configuration:**
- Point `docs.cloudigan.net` to HAProxy VIP (10.92.3.33)
- Enable SSL certificate
- Configure proxy headers

---

### Step 6: Create Initial Documentation Structure ⏳
**Timeline:** 2-3 hours  
**Dependencies:** BookStack deployed and accessible

**Structure:**
```
BookStack Shelves (Clients):
├── Cloudigan Internal
│   ├── Infrastructure Documentation
│   ├── MSP Platform Guide
│   ├── Runbooks
│   └── Policies & Procedures
│
├── Client Template (for future clients)
│   ├── Overview
│   ├── Network Documentation
│   ├── Server Documentation
│   ├── Application Documentation
│   ├── Contacts
│   └── Runbooks
│
└── [Future Client Shelves]
```

**Initial Content:**
1. Import existing documentation from homelab-nexus
2. Create MSP platform documentation
3. Create client onboarding template
4. Document SSO setup
5. Create user guides

---

### Step 7: Configure Entra ID App Registrations ⏳
**Timeline:** 1 hour  
**Dependencies:** Authentik and BookStack deployed

**App Registrations to Create:**

#### 1. Authentik (Upstream Federation)
```
Name: Cloudigan Authentik
Type: Web Application
Redirect URI: https://auth.cloudigan.net/source/oidc/callback/entra-id/
Scopes: openid, profile, email, User.Read
```

#### 2. BookStack (Direct OIDC)
```
Name: Cloudigan BookStack
Type: Web Application
Redirect URI: https://docs.cloudigan.net/oidc/callback
Scopes: openid, profile, email
```

**Store Credentials:**
- Save Client IDs and Secrets in 1Password
- Vault: `MSP-Platform-SSO`
- Document in `MSP-PLATFORM-SSO-COMPATIBILITY.md`

---

### Step 8: User Provisioning & Testing ⏳
**Timeline:** 2 hours  
**Dependencies:** All services deployed and configured

**Tasks:**
1. Create test users in Entra ID
2. Test SSO flow: Entra ID → Authentik → BookStack
3. Test direct OIDC: Entra ID → BookStack
4. Verify user attributes mapping
5. Test logout flow
6. Document any issues

**Test Scenarios:**
- [ ] New user first login (auto-provisioning)
- [ ] Existing user login
- [ ] User logout
- [ ] Session timeout
- [ ] Password reset (via Entra ID)
- [ ] MFA enforcement (if enabled in Entra ID)

---

## Phase 1 Success Criteria

### Technical
- ✅ Authentik deployed and accessible
- ✅ BookStack blue-green deployment working
- ✅ SSO authentication working (Entra ID → Authentik → BookStack)
- ✅ PostgreSQL cluster upgraded and stable
- ✅ All services monitored in Grafana
- ✅ Backups configured for all new containers

### Functional
- ✅ Users can log in with Entra ID credentials
- ✅ Documentation accessible via docs.cloudigan.net
- ✅ Blue-green switching works for BookStack
- ✅ Client documentation structure created
- ✅ Zero downtime during deployment

### Documentation
- ✅ All deployment procedures documented
- ✅ Runbooks created for each service
- ✅ User guides created
- ✅ Troubleshooting guides documented

---

## Rollback Plan

### If Authentik Deployment Fails
1. Stop Authentik container
2. Remove from Netbox/NPM
3. Continue with BookStack using local auth
4. Retry Authentik deployment later

### If BookStack Deployment Fails
1. Stop BookStack containers
2. Remove from HAProxy/NPM
3. Use existing documentation methods
4. Debug and retry

### If PostgreSQL Upgrade Fails
1. Rollback to CT131 as primary (see POSTGRESQL-REPLICA-FIRST-UPGRADE.md)
2. Restore from backup if needed
3. Postpone MSP platform deployment

---

## Post-Phase 1 Tasks

### Immediate (Week 2)
1. Monitor service stability for 1 week
2. Gather user feedback
3. Document lessons learned
4. Plan Phase 2 deployment

### Phase 2 Preparation (Week 3-4)
1. Deploy Plane (Project Management)
2. Deploy Zammad (Ticketing)
3. Integrate with BookStack
4. Onboard first pilot client

---

## Resource Requirements

### Compute
- **New Containers:** 4 (Authentik, BookStack Blue/Green, Ansible)
- **Total vCPU:** 10 cores
- **Total RAM:** 14GB
- **Total Storage:** 128GB

### Database
- **New Databases:** 2 (authentik, bookstack)
- **Estimated Size:** 1-2GB total
- **Connections:** ~30 concurrent

### Network
- **Bandwidth:** Minimal (<10 Mbps)
- **Latency:** <10ms to PostgreSQL
- **DNS Records:** 4 new (auth, docs, bookstack-blue, bookstack-green)

---

## Monitoring & Alerts

### Metrics to Monitor
- **Authentik:**
  - Login success/failure rate
  - Response time
  - Active sessions
  - Federation errors

- **BookStack:**
  - Page load time
  - Search performance
  - Database query time
  - Active users

- **PostgreSQL:**
  - Connection count
  - Query performance
  - Replication lag
  - Disk usage

### Alerts to Configure
- Service down (any container)
- High response time (>2 seconds)
- Database connection errors
- Replication lag >5 seconds
- Disk usage >80%

---

## Timeline Summary

**Week 1:**
- Day 1: Upgrade PostgreSQL cluster (2-3 hours)
- Day 2: Deploy Authentik (2-3 hours)
- Day 3: Deploy BookStack Blue (1-2 hours)
- Day 4: Deploy BookStack Green + HAProxy config (1-2 hours)
- Day 5: Configure Entra ID + Testing (2-3 hours)

**Week 2:**
- Day 1-2: Create documentation structure
- Day 3-4: User testing and feedback
- Day 5: Documentation and wrap-up

**Total Effort:** ~20-25 hours

---

## Next Steps (Immediate)

1. ✅ **Backups Complete** - All 28 containers backed up
2. ✅ **Ansible Deployed** - CT183 ready for automation
3. ✅ **Network Documented** - TP-Link switch and ER7206 documented
4. ⏳ **PostgreSQL Upgrade** - Schedule for this week
5. ⏳ **Authentik Deployment** - After PostgreSQL upgrade
6. ⏳ **BookStack Deployment** - After Authentik

---

**Status:** Ready to begin Phase 1 deployment  
**Blocker:** Proxmox host update (scheduled for tonight)  
**Next Action:** Upgrade PostgreSQL cluster after Proxmox update complete
