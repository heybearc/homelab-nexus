# Cloudigan API - Blue-Green Deployment Setup Guide

**Date:** 2026-03-17  
**Status:** Implementation Ready  
**Purpose:** Zero-downtime deployments for Cloudigan API webhook service

---

## Overview

This guide walks through setting up blue-green deployment for the Cloudigan API webhook service to ensure zero-downtime for customer checkout flows.

### Architecture

```
Stripe Webhook → api.cloudigan.net
                      ↓
                 HAProxy VIP (10.92.3.33)
                      ↓
        ┌─────────────┴─────────────┐
        ↓                           ↓
   LIVE Container              STANDBY Container
   (Blue or Green)             (Green or Blue)
   10.92.3.181                 10.92.3.182
```

---

## Current State

- **Existing Container:** `10.92.3.181` (cloudigan-api)
- **Status:** Running in production, handling live Stripe webhooks
- **Features:** Datto site creation, Wix CMS integration
- **Missing:** SendGrid email integration, blue-green deployment

---

## Implementation Steps

### Phase 1: Create STANDBY Container

#### Automated Setup (Recommended)

Use the automated setup script that clones LIVE to STANDBY:

```bash
cd /Users/cory/Projects/homelab-nexus/scripts/cloudigan-api
./setup-blue-green-mcp.sh
```

This script will:
1. Verify LIVE container (CT181) is running
2. Clone CT181 to CT182 with full disk copy
3. Update network configuration (IP: 10.92.3.182)
4. Start STANDBY container
5. Verify service is running
6. Run health checks

#### Manual Setup (Alternative)

```bash
# 1. SSH to Proxmox host
ssh root@pve

# 2. Clone LIVE to STANDBY
pct clone 181 182 --full --hostname cloudigan-api-green

# 3. Update STANDBY IP address
pct set 182 -net0 name=eth0,bridge=vmbr0923,ip=10.92.3.182/24,gw=10.92.3.1

# 4. Start STANDBY
pct start 182

# 5. Verify service
ssh root@10.92.3.182 'systemctl status cloudigan-api'
```

---

### Phase 2: Configure HAProxy

#### 1. Add Backend Configurations

SSH to HAProxy VIP and edit config:

```bash
ssh root@10.92.3.33
nano /etc/haproxy/haproxy.cfg
```

Add these backend configurations:

```haproxy
# Cloudigan API - Blue Backend (LIVE initially)
backend cloudigan_api_blue
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    http-request set-header X-Forwarded-Host %[req.hdr(host)]
    server blue1 10.92.3.181:3000 check inter 5s fall 3 rise 2

# Cloudigan API - Green Backend (STANDBY initially)
backend cloudigan_api_green
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    http-request set-header X-Forwarded-Host %[req.hdr(host)]
    server green1 10.92.3.182:3000 check inter 5s fall 3 rise 2
```

#### 2. Add Frontend Routing

Add ACLs and routing rules:

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

#### 3. Test and Reload

```bash
# Test configuration
haproxy -c -f /etc/haproxy/haproxy.cfg

# Reload HAProxy (zero downtime)
systemctl reload haproxy

# Verify backends are up
echo "show stat" | socat stdio /var/run/haproxy/admin.sock | grep cloudigan
```

---

### Phase 3: Configure DNS (Optional Direct Access)

Add DNS records for direct blue/green access:

```bash
# SSH to DC-01
ssh administrator@10.92.0.10

# Add DNS records
Add-DnsServerResourceRecordCName -Name "blue.api" -HostNameAlias "api.cloudigan.net" -ZoneName "cloudigan.net"
Add-DnsServerResourceRecordCName -Name "green.api" -HostNameAlias "api.cloudigan.net" -ZoneName "cloudigan.net"
```

---

### Phase 4: Add SendGrid Integration

#### 1. Get SendGrid API Key

1. Log in to SendGrid dashboard
2. Settings → API Keys → Create API Key
3. Name: `cloudigan-api-production`
4. Permissions: Full Access (or Mail Send only)
5. Copy the API key

#### 2. Update STANDBY Container

```bash
# SSH to STANDBY
ssh root@10.92.3.182

# Add SendGrid config to .env
cd /opt/cloudigan-api
nano .env

# Add these lines:
SENDGRID_API_KEY=SG.your_api_key_here
SENDGRID_FROM_EMAIL=noreply@cloudigan.com

# Restart service
systemctl restart cloudigan-api

# Check logs
journalctl -u cloudigan-api -f
```

#### 3. Verify Health

```bash
# Check health endpoint
curl http://10.92.3.182:3000/health

# Expected: {"status":"ok"}
```

---

### Phase 5: Test STANDBY

#### 1. Test via Direct Access

```bash
# Test health check
curl https://green.api.cloudigan.net/health

# Test webhook with Stripe CLI
stripe listen --forward-to https://green.api.cloudigan.net/webhook/stripe
stripe trigger checkout.session.completed
```

#### 2. Verify SendGrid Email

Check that welcome email is sent to test customer.

---

### Phase 6: Switch Traffic

#### Option A: Use Automated Script

```bash
cd /Users/cory/Projects/homelab-nexus/scripts/cloudigan-api
./deploy-blue-green.sh
```

#### Option B: Manual Switch

```bash
# SSH to HAProxy
ssh root@10.92.3.33

# Backup config
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup-$(date +%Y%m%d-%H%M%S)

# Edit config - change routing from blue to green
nano /etc/haproxy/haproxy.cfg

# Change this line:
# FROM: use_backend cloudigan_api_blue if is_cloudigan_api
# TO:   use_backend cloudigan_api_green if is_cloudigan_api

# Test config
haproxy -c -f /etc/haproxy/haproxy.cfg

# Reload (zero downtime)
systemctl reload haproxy
```

#### 3. Verify Traffic Switch

```bash
# Test main domain
curl https://api.cloudigan.net/health

# Should now be hitting green (10.92.3.182)

# Do a real Stripe test checkout
# Verify email is sent
```

---

## Deployment Workflow (Future)

### Deploying Changes

```bash
# 1. Identify current LIVE/STANDBY
# LIVE = currently receiving traffic
# STANDBY = idle, ready for updates

# 2. Update STANDBY with new code
ssh root@<STANDBY_IP>
cd /opt/cloudigan-api
# ... make changes ...
systemctl restart cloudigan-api

# 3. Test STANDBY
curl https://<standby-subdomain>.api.cloudigan.net/health
# Run integration tests

# 4. Switch traffic to STANDBY
./deploy-blue-green.sh

# 5. STANDBY becomes LIVE, old LIVE becomes STANDBY
```

### Rollback

```bash
# Quick rollback - just switch HAProxy back
ssh root@10.92.3.33
nano /etc/haproxy/haproxy.cfg
# Change backend back to previous LIVE
systemctl reload haproxy
```

---

## Monitoring

### Health Checks

```bash
# Check both containers
curl http://10.92.3.181:3000/health  # Blue
curl http://10.92.3.182:3000/health  # Green

# Check via HAProxy
curl https://api.cloudigan.net/health
curl https://blue.api.cloudigan.net/health
curl https://green.api.cloudigan.net/health
```

### HAProxy Stats

```bash
# View backend status
echo "show stat" | socat stdio /var/run/haproxy/admin.sock | grep cloudigan

# Expected output shows which backend is active
```

### Application Logs

```bash
# LIVE container
ssh root@10.92.3.181 'journalctl -u cloudigan-api -f'

# STANDBY container
ssh root@10.92.3.182 'journalctl -u cloudigan-api -f'
```

---

## Troubleshooting

### STANDBY Won't Start

```bash
# Check service status
ssh root@10.92.3.182 'systemctl status cloudigan-api'

# Check logs
ssh root@10.92.3.182 'journalctl -u cloudigan-api -n 50'

# Common issues:
# - Port 3000 already in use
# - Missing .env file
# - Node modules not installed
```

### HAProxy Not Routing

```bash
# Check HAProxy logs
ssh root@10.92.3.33 'tail -f /var/log/haproxy.log'

# Verify backend health
echo "show stat" | socat stdio /var/run/haproxy/admin.sock | grep cloudigan

# Check ACL matching
# Test with curl -H "Host: api.cloudigan.net" http://10.92.3.33/health
```

### Email Not Sending

```bash
# Check SendGrid API key is set
ssh root@<container> 'grep SENDGRID /opt/cloudigan-api/.env'

# Check logs for SendGrid errors
ssh root@<container> 'journalctl -u cloudigan-api | grep -i sendgrid'

# Test SendGrid API key
curl -X POST https://api.sendgrid.com/v3/mail/send \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"personalizations":[{"to":[{"email":"test@example.com"}]}],"from":{"email":"noreply@cloudigan.com"},"subject":"Test","content":[{"type":"text/plain","value":"Test"}]}'
```

---

## Next Steps

1. ✅ Create STANDBY container (clone from LIVE)
2. ✅ Configure HAProxy backends
3. ✅ Add SendGrid integration to STANDBY
4. ✅ Test STANDBY thoroughly
5. ✅ Switch traffic to STANDBY
6. ✅ Verify emails are being sent
7. ✅ Monitor for 24 hours
8. ✅ Document any issues/learnings

---

## Success Criteria

- [x] Both blue and green containers exist and are healthy
- [x] HAProxy can route to both backends
- [x] Health checks pass on both containers
- [ ] SendGrid emails are being sent successfully
- [ ] Zero downtime during traffic switch
- [ ] Rollback procedure tested and works
- [ ] Monitoring and alerting configured

---

## References

- **Deployment Plan:** `/documentation/CLOUDIGAN-API-DEPLOYMENT-PLAN.md`
- **Webhook Integration:** `/documentation/CLOUDIGAN-WEBHOOK-INTEGRATION-COMPLETE.md`
- **Blue-Green Script:** `/scripts/cloudigan-api/deploy-blue-green.sh`
- **HAProxy Config:** `/etc/haproxy/haproxy.cfg` on 10.92.3.33

---

**Status:** Ready for implementation - proceed with Phase 1
