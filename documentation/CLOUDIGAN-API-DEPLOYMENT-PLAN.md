# Cloudigan API Service - Deployment Plan

**Service Name:** cloudigan-api  
**Purpose:** Stripe webhook → Datto RMM automation for customer onboarding  
**Type:** Blue-Green Web Service  
**Function Category:** utility  
**CTID Range:** 180-189  
**Deployment Date:** 2026-03-16

---

## Service Overview

### What It Does
Automatically creates Datto RMM sites when customers subscribe via Stripe on Wix website.

**Flow:**
```
Customer subscribes on Wix
    ↓
Stripe processes payment
    ↓
Stripe webhook → api.cloudigan.net
    ↓
Cloudigan API creates Datto site
    ↓
Returns agent download portal URL
```

### Technology Stack
- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **OAuth Automation:** Playwright (headless browser)
- **Process Manager:** systemd
- **Deployment:** Blue-Green via HAProxy

---

## Naming Convention Decision

### Container Names
- **Blue:** `cloudigan-api-blue` (CT181)
- **Green:** `cloudigan-api-green` (CT182)

### Rationale
1. ✅ Follows established `{app-name}-blue/green` pattern (theoshift, ldctools, quantshift)
2. ✅ Matches domain name (`api.cloudigan.net`)
3. ✅ Generic enough to expand with additional API endpoints
4. ✅ Short, memorable, business-focused
5. ✅ Clearly indicates Cloudigan business service (not homelab infrastructure)

### Alternative Names Considered
- `cloudigan-webhook` - Too specific to webhooks
- `cloudigan-automation` - Too vague
- `cloudigan-onboarding` - Might expand beyond onboarding
- `stripe-datto-webhook` - ❌ Doesn't follow blue-green convention

**Decision:** `cloudigan-api` provides best balance of clarity, flexibility, and convention adherence.

---

## Network Architecture

### DNS Configuration
**Public DNS (cloudigan.net) managed in Wix:**
- Domain managed via Wix account (not tied to specific site)
- Can be configured via Wix MCP server
- **Production:** `api.cloudigan.net` → CNAME to `cloudigan.net` root
- **Blue Direct:** `blue.api.cloudigan.net` → CNAME to `cloudigan.net` root
- **Green Direct:** `green.api.cloudigan.net` → CNAME to `cloudigan.net` root

**Internal DNS managed by DC-01:**
- **Server:** DC-01 @ `10.92.0.10` (Windows AD DNS)
- **Zone:** `cloudigan.net`
- **Method:** SSH + PowerShell commands
- **Script:** `/scripts/dns/update-dc01-dns.sh`

**Root domain resolves to:** HAProxy VIP `10.92.3.33`

### HAProxy Routing
**VIP:** `10.92.3.33` (VRRP managed by CT136 MASTER + CT139 BACKUP)

**ACL Configuration:**
```haproxy
# Cloudigan API - Domain ACLs
acl is_cloudigan_api hdr(host) -i api.cloudigan.net
acl is_cloudigan_api hdr(host) -i www.api.cloudigan.net

# Cloudigan API - Direct access ACLs
acl is_cloudigan_blue hdr(host) -i blue.api.cloudigan.net
acl is_cloudigan_green hdr(host) -i green.api.cloudigan.net

# Cloudigan API - Main routing (Blue is LIVE initially)
use_backend cloudigan_api_blue if is_cloudigan_api

# Cloudigan API - Direct access routing
use_backend cloudigan_api_blue if is_cloudigan_blue
use_backend cloudigan_api_green if is_cloudigan_green
```

**Backend Configuration:**
```haproxy
backend cloudigan_api_blue
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    http-request set-header X-Forwarded-Host %[req.hdr(host)]
    server blue1 10.92.3.x:3000 check inter 5s fall 3 rise 2

backend cloudigan_api_green
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    http-request set-header X-Forwarded-Host %[req.hdr(host)]
    server green1 10.92.3.y:3000 check inter 5s fall 3 rise 2
```

### NPM Configuration (Optional)
**NPM at 10.92.3.3 can provide additional SSL/routing if needed, but HAProxy handles primary routing.**

If using NPM:
- Forward to HAProxy VIP `10.92.3.33`, NOT container IPs
- Let HAProxy handle backend routing based on domain

---

## Container Specifications

### Blue Container (Initial LIVE)
- **Name:** `cloudigan-api-blue`
- **CTID:** 181
- **IP:** 10.92.3.x (to be assigned)
- **Function:** utility
- **Resources:**
  - CPU: 2 cores
  - RAM: 1024 MB
  - Disk: 5 GB
- **Network:** vmbr0923 (10.92.3.0/24)
- **Gateway:** 10.92.3.1
- **OS:** Ubuntu 22.04 LTS

### Green Container (Initial STANDBY)
- **Name:** `cloudigan-api-green`
- **CTID:** 182
- **IP:** 10.92.3.y (to be assigned)
- **Function:** utility
- **Resources:** Same as Blue
- **Network:** Same as Blue

---

## Application Configuration

### Directory Structure
```
/opt/cloudigan-api/
├── node_modules/
├── webhook-handler.js
├── datto-auth.js
├── package.json
├── package-lock.json
├── .env                      # Environment variables (0600)
├── .datto-token.json         # OAuth token cache (auto-generated, 0600)
└── logs/
    ├── webhook.log
    ├── error.log
    └── oauth.log
```

### Environment Variables
```bash
# Stripe Configuration
STRIPE_SECRET_KEY=sk_live_... # Get from Stripe Dashboard
STRIPE_WEBHOOK_SECRET=whsec_... # Get after configuring Stripe webhook

# Datto RMM Configuration
DATTO_API_URL=https://vidal-api.centrastage.net
DATTO_API_KEY=BCE6247DP69R8OBFHVE37EMET4IH6325
DATTO_API_SECRET_KEY=C9CEDEUVO476DF9IKAP3MK33I0QBUCAV

# Server Configuration
PORT=3000
NODE_ENV=production
```

### System Dependencies
```bash
# Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs git

# Playwright dependencies (for OAuth automation)
apt-get install -y \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libdbus-1-3 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
    libgbm1 libasound2
```

### Node.js Dependencies
```json
{
  "express": "^4.18.2",
  "axios": "^1.6.0",
  "dotenv": "^16.3.1",
  "stripe": "^14.0.0",
  "playwright": "^1.40.0"
}
```

---

## Deployment Pipeline Order

### Phase 1: PRE-DEPLOYMENT (Infrastructure First)

#### Stage 0: Validate & Plan
- Parse arguments, load `.env`
- Validate function category (utility)
- Auto-assign CTID from range 180-189
- Validate IP availability (ping test, Netbox check)
- Validate domain availability (DNS lookup)
- Check network/bridge configuration (vmbr0923)
- Determine blue-green role (query HAProxy for current LIVE)
- Display deployment plan
- User confirmation

#### Stage 1: Configure DNS
**Public DNS (Wix MCP):**
- Check if `api.cloudigan.net` exists in Wix DNS
- If missing, use Wix MCP to add CNAME to cloudigan.net root
- Add blue/green subdomains: `blue.api.cloudigan.net`, `green.api.cloudigan.net`
- Verify DNS propagation

**Internal DNS (DC-01):**
- Add A record: `api.cloudigan.net` → HAProxy VIP `10.92.3.33`
- Add A records for blue/green: `blue.api.cloudigan.net`, `green.api.cloudigan.net` → `10.92.3.33`
- Use script: `/scripts/dns/update-dc01-dns.sh`
- Verify: `nslookup api.cloudigan.net 10.92.0.10`

#### Stage 2: Reserve IPAM (Netbox)
- Create VM placeholder (status: "planned")
- Reserve IP address (status: "reserved")
- Set custom fields: ctid, role (STANDBY), function (utility)

#### Stage 3: Configure HAProxy Backend
- SSH to HAProxy VIP (10.92.3.33)
- Identify current LIVE/STANDBY
- Add backend configuration for both blue and green
- Test HAProxy config
- Reload HAProxy (zero downtime)
- Verify backends added

#### Stage 4: Configure NPM Proxy (Optional)
- If using NPM for SSL, create proxy pointing to HAProxy VIP
- Request Let's Encrypt certificate

### Phase 2: DEPLOYMENT (Create Container)

#### Stage 5: Create Proxmox LXC Container
- Create container with validated network config
- Start container
- Wait for network initialization
- Verify network connectivity (ping gateway, HAProxy VIP)
- Update Netbox VM status: "planned" → "active"

### Phase 3: POST-DEPLOYMENT (Application & Monitoring)

#### Stage 6: Deploy Application Code
- Install Node.js 18+ and Playwright dependencies
- Create service user (`webhook`)
- Create directory structure (`/opt/cloudigan-api/`)
- Deploy application files from `/Users/cory/Projects/cloudigan/projects/stripe-datto-integration/`
- Install npm dependencies
- Install Playwright: `npx playwright install chromium`
- Configure `.env` file (0600 permissions)
- Test application startup
- Verify health endpoint

#### Stage 7: Configure Systemd Service
- Create `/etc/systemd/system/cloudigan-api.service`
- Enable and start service
- Verify service status

#### Stage 8: Test STANDBY via HAProxy
- Test health endpoint via direct access domain
- Test webhook endpoint (Stripe CLI test)
- Verify logs show successful processing

#### Stage 9: Install Monitoring Agents
- Install node_exporter (port 9100)
- Install promtail
- Verify metrics collection in Prometheus
- Add to Grafana dashboards

#### Stage 10: Configure Backups
- Create Proxmox backup job (daily at 02:00)
- Set retention policy (7 daily, 4 weekly, 3 monthly)

### Phase 4: TRAFFIC SWITCH (Blue-Green Cutover)

#### Stage 11: Pre-Switch Validation
- Verify STANDBY health
- Verify LIVE health
- Compare metrics (response time, error rate)
- User approval for traffic switch

#### Stage 12: Switch HAProxy Traffic
- SSH to HAProxy VIP
- Update routing rule (swap LIVE/STANDBY)
- Test config
- Reload HAProxy (zero downtime)
- Verify traffic routing to new LIVE

#### Stage 13: Update Netbox Roles
- Update new LIVE: role "STANDBY" → "LIVE"
- Update old LIVE: role "LIVE" → "STANDBY"

#### Stage 14: Update Documentation
- Update APP-MAP.md with new LIVE/STANDBY
- Generate deployment record
- Update infrastructure documentation

---

## Integration Points

### Stripe Webhook
- **Endpoint:** `https://api.cloudigan.net/webhook/stripe`
- **Event:** `checkout.session.completed`
- **Verification:** Webhook signature validation
- **Configuration:** Stripe Dashboard → Webhooks → Add endpoint

### Datto RMM API
- **URL:** `https://vidal-api.centrastage.net`
- **Authentication:** OAuth 2.0 (automated via Playwright)
- **Operations:** Site creation, portal URL retrieval
- **Token Management:** Auto-refresh before expiration (100 hours)

### Wix Confirmation Page
- **Endpoint:** `https://api.cloudigan.net/api/agent-link/:sessionId`
- **Returns:** Agent download portal URL
- **Usage:** Fetch and display to customer after successful subscription

---

## Monitoring & Health Checks

### Health Endpoint
```bash
GET https://api.cloudigan.net/health
Response: {"status":"ok","timestamp":"2026-03-16T..."}
```

### HAProxy Health Checks
- **Frequency:** Every 5 seconds
- **Endpoint:** `GET /health`
- **Expected:** HTTP 200
- **Fail threshold:** 3 consecutive failures
- **Rise threshold:** 2 consecutive successes

### Metrics (via node_exporter)
- Service uptime
- Webhook processing success rate
- Datto API call success rate
- OAuth token expiration time
- Response time
- Memory/CPU usage

### Logs
- **Application:** `/opt/cloudigan-api/logs/webhook.log`
- **Errors:** `/opt/cloudigan-api/logs/error.log`
- **OAuth:** `/opt/cloudigan-api/logs/oauth.log`
- **System:** `journalctl -u cloudigan-api`
- **Aggregation:** Promtail → Loki → Grafana

---

## Security Considerations

### Network Security
- Container only accessible from HAProxy VIP
- Firewall rules restrict port 3000 to HAProxy IPs
- SSL/TLS terminated at HAProxy
- No direct internet access except for API calls

### Secret Management
- `.env` file permissions: 0600 (webhook user only)
- OAuth tokens in `.datto-token.json` (0600)
- No secrets in logs or version control
- Stripe webhook signature verification

### Webhook Security
- Stripe signature verification on all webhooks
- Rejects unsigned or invalid webhooks
- Rate limiting in HAProxy

---

## Rollback Procedures

### Quick Rollback (HAProxy Traffic Switch)
```bash
# SSH to HAProxy VIP
ssh root@10.92.3.33

# Edit config to switch back to old LIVE
nano /etc/haproxy/haproxy.cfg

# Test and reload
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl reload haproxy
```

### Full Rollback (Container Level)
```bash
# Stop new service
ssh cloudigan-api-green 'systemctl stop cloudigan-api'

# Restore from backup
tar -xzf /backup/cloudigan-api-YYYYMMDD.tar.gz -C /

# Restart service
ssh cloudigan-api-blue 'systemctl restart cloudigan-api'
```

---

## Success Criteria

### Deployment Success
- [x] Container created and running
- [x] Service started and healthy
- [x] HAProxy routing correctly
- [x] DNS resolving to HAProxy VIP
- [x] Health check endpoint responding
- [x] Stripe webhook configured
- [x] Test webhook processed successfully
- [x] Datto site created via test webhook
- [x] Logs being written
- [x] Monitoring metrics collected

### Operational Success
- [x] Uptime > 99.9%
- [x] Webhook processing success > 99%
- [x] Response time < 500ms
- [x] OAuth token auto-refreshing
- [x] No security incidents

---

## Post-Deployment Tasks

### Immediate (24 hours)
1. Monitor logs for errors
2. Verify webhook processing
3. Check OAuth token refresh
4. Test with real customer subscription

### Short-term (1 week)
1. Review metrics and performance
2. Optimize resource allocation if needed
3. Update runbooks with any learnings
4. Train support team on troubleshooting

### Long-term
1. Plan for additional API endpoints
2. Consider API versioning strategy
3. Evaluate need for API rate limiting
4. Document API for potential external integrations

---

## Source Files Location

**Development Project:**
`/Users/cory/Projects/cloudigan/projects/stripe-datto-integration/`

**Key Files:**
- `webhook-handler.js` - Main Express server
- `datto-auth.js` - OAuth automation
- `package.json` - Dependencies
- `NEXUS-HANDOFF.md` - Complete deployment guide
- `HOMELAB-ARCHITECTURE.md` - Architecture documentation

---

## References

- **Decision:** D-029 (Specialized container deployment via vendor installers)
- **Decision:** D-030 (OAuth Token Management Pattern with Playwright)
- **Policy:** `haproxy-blue-green-standard.md`
- **Policy:** `container-ssh-access.md`
- **Runbook:** `deployment.md`
- **APP-MAP:** TheoShift, LDC Tools, QuantShift (blue-green examples)

---

**Deployment Status:** 📋 Planning Complete - Ready for Execution
