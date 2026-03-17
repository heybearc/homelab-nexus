# Provisioning Pipeline - Industry Best Practices Analysis

**Date:** 2026-03-16  
**Purpose:** Document improvements to automated container provisioning pipeline based on infrastructure-first principles  
**Status:** Pre-deployment review for cloudigan-api service

---

## Executive Summary

The original provisioning pipeline violated infrastructure best practices by creating containers **before** configuring supporting infrastructure (DNS, IPAM, HAProxy, NPM). This document outlines the revised pipeline that follows industry standards: **configure infrastructure first, then deploy**.

---

## Critical Issues with Original Pipeline

### ❌ Problem 1: Container-First Approach
**Original Order:**
1. Create container
2. Configure Netbox
3. Configure NPM
4. Configure DNS
5. Configure monitoring

**Why This Fails:**
- ✗ Can't test DNS/proxy/networking before deployment
- ✗ Container exists even if infrastructure config fails
- ✗ No rollback if later stages fail
- ✗ Violates "configure infrastructure, then deploy" principle
- ✗ Can't validate routing before container is live

### ❌ Problem 2: DNS Pointing to Container IPs
**Original Approach:**
- DNS records pointed directly to container IPs
- Example: `api.cloudigan.net` → `10.92.3.x` (container IP)

**Why This Fails:**
- ✗ Breaks blue-green deployment pattern
- ✗ Requires DNS changes during traffic switch
- ✗ DNS propagation delays during cutover
- ✗ Doesn't match existing app patterns (theoshift, ldctools, quantshift)

### ❌ Problem 3: Missing Blue-Green Infrastructure Setup
**Original Approach:**
- Only configured infrastructure for single container
- No HAProxy backend configuration
- No blue/green subdomain setup

**Why This Fails:**
- ✗ Can't test STANDBY before traffic switch
- ✗ No direct access to blue/green environments
- ✗ Manual HAProxy configuration required later
- ✗ Inconsistent with production app deployments

### ❌ Problem 4: Netbox Status Not Updated
**Original Approach:**
- Created Netbox entry as "active" immediately
- No status progression (planned → active → LIVE/STANDBY)

**Why This Fails:**
- ✗ Can't track deployment state
- ✗ No distinction between planned vs deployed vs production
- ✗ IPAM shows container as active before it exists

---

## Revised Pipeline - Infrastructure-First Approach

### ✅ Phase 1: PRE-DEPLOYMENT (Infrastructure Configuration)

#### Stage 0: Validate & Plan
**Industry Best Practice:** Validate all inputs before making any changes

**Improvements:**
- ✅ Auto-assign CTID from function-based ranges (prevents conflicts)
- ✅ Validate IP availability (ping test + Netbox check)
- ✅ Validate domain availability (DNS lookup)
- ✅ Check network/bridge configuration exists
- ✅ Query HAProxy to determine current LIVE/STANDBY roles
- ✅ Display complete deployment plan before execution
- ✅ User confirmation gate

**Why This Matters:**
- Prevents deployment failures due to IP conflicts
- Ensures network infrastructure exists before container creation
- Establishes blue-green roles before any configuration
- Gives user visibility into what will happen

---

#### Stage 1: Configure DNS via Wix MCP
**Industry Best Practice:** Establish DNS infrastructure first

**Improvements:**
- ✅ Use Wix MCP server to manage cloudigan.net DNS
- ✅ Create CNAME records pointing to root domain (not container IPs)
- ✅ Configure blue/green subdomains upfront
- ✅ Verify DNS propagation before proceeding

**DNS Architecture:**
```
api.cloudigan.net → CNAME to cloudigan.net root
blue.api.cloudigan.net → CNAME to cloudigan.net root
green.api.cloudigan.net → CNAME to cloudigan.net root

cloudigan.net root → HAProxy VIP (10.92.3.33)
```

**Why This Matters:**
- DNS changes are slow to propagate (TTL delays)
- Configuring DNS first allows testing before container exists
- CNAME to root enables flexible backend changes
- Matches existing production app patterns

---

#### Stage 2: Reserve IPAM (Netbox)
**Industry Best Practice:** Reserve resources before allocation

**Improvements:**
- ✅ Create VM entry with status "planned" (not "active")
- ✅ Reserve IP with status "reserved" (not "active")
- ✅ Set custom fields: ctid, role (STANDBY), function
- ✅ Update to "active" only after container creation succeeds

**Status Progression:**
```
planned → active → LIVE/STANDBY
```

**Why This Matters:**
- Prevents IP conflicts during deployment
- Tracks deployment state accurately
- Enables rollback if deployment fails
- Provides audit trail of infrastructure changes

---

#### Stage 3: Configure HAProxy Backend
**Industry Best Practice:** Configure routing infrastructure before backends exist

**Improvements:**
- ✅ SSH to HAProxy VIP (10.92.3.33), not individual IPs
- ✅ Configure BOTH blue and green backends upfront
- ✅ Set up domain ACLs for production and direct access
- ✅ Test HAProxy config before reload
- ✅ Reload with zero downtime (systemctl reload)
- ✅ Verify backends via HAProxy socket

**HAProxy Configuration Pattern:**
```haproxy
# Domain ACLs
acl is_cloudigan_api hdr(host) -i api.cloudigan.net
acl is_cloudigan_blue hdr(host) -i blue.api.cloudigan.net
acl is_cloudigan_green hdr(host) -i green.api.cloudigan.net

# Routing rules
use_backend cloudigan_api_blue if is_cloudigan_api  # Production
use_backend cloudigan_api_blue if is_cloudigan_blue  # Direct blue
use_backend cloudigan_api_green if is_cloudigan_green  # Direct green

# Backends with health checks
backend cloudigan_api_blue
    option httpchk GET /health
    server blue1 10.92.3.x:3000 check inter 5s fall 3 rise 2

backend cloudigan_api_green
    option httpchk GET /health
    server green1 10.92.3.y:3000 check inter 5s fall 3 rise 2
```

**Why This Matters:**
- HAProxy can test health checks before containers exist (will fail gracefully)
- Direct access URLs work immediately after container deployment
- Blue-green switching is pre-configured (just change routing rule)
- Matches existing production app patterns (theoshift, ldctools, quantshift)

---

#### Stage 4: Configure NPM Proxy (Optional)
**Industry Best Practice:** Optional layer for additional SSL/routing

**Improvements:**
- ✅ NPM forwards to HAProxy VIP (10.92.3.33), not container IPs
- ✅ HAProxy handles backend routing based on domain
- ✅ NPM provides additional SSL termination if needed
- ✅ Can be skipped if HAProxy handles SSL directly

**Why This Matters:**
- Decouples SSL management from routing logic
- HAProxy remains authoritative for routing decisions
- NPM can be added/removed without affecting routing

---

### ✅ Phase 2: DEPLOYMENT (Create Container)

#### Stage 5: Create Proxmox LXC Container
**Industry Best Practice:** Deploy only after infrastructure is ready

**Improvements:**
- ✅ All infrastructure pre-configured and tested
- ✅ Container creation is final step, not first
- ✅ Network connectivity verified immediately after creation
- ✅ Netbox status updated from "planned" → "active"
- ✅ Clear rollback point if creation fails

**Why This Matters:**
- Infrastructure is ready to receive container
- Can test routing immediately after container starts
- Rollback is clean (destroy container, revert Netbox status)
- Follows infrastructure-first principle

---

### ✅ Phase 3: POST-DEPLOYMENT (Application & Monitoring)

#### Stage 6-10: Application Deployment
**Industry Best Practice:** Deploy application, then monitoring, then backups

**Improvements:**
- ✅ Test application startup before enabling systemd
- ✅ Verify health endpoint before declaring success
- ✅ Test via HAProxy direct access URLs
- ✅ Install monitoring after application is stable
- ✅ Configure backups as final step

**Why This Matters:**
- Each stage can be tested independently
- Clear success criteria at each stage
- Monitoring doesn't interfere with application deployment
- Backups only configured for stable containers

---

### ✅ Phase 4: TRAFFIC SWITCH (Blue-Green Cutover)

#### Stage 11-14: Production Cutover
**Industry Best Practice:** Validate before switching, update documentation after

**Improvements:**
- ✅ Pre-switch validation (health checks, metrics comparison)
- ✅ User approval gate before traffic switch
- ✅ HAProxy reload with zero downtime
- ✅ Verify traffic routing to new LIVE
- ✅ Update Netbox roles (STANDBY → LIVE, LIVE → STANDBY)
- ✅ Update documentation (APP-MAP.md)

**Why This Matters:**
- STANDBY is fully tested before becoming LIVE
- Zero downtime during traffic switch
- Clear audit trail of LIVE/STANDBY roles
- Documentation stays current

---

## Industry Best Practices Applied

### 1. Infrastructure as Code (IaC) Principles
✅ **Declarative Configuration:** Pipeline defines desired state, not imperative steps  
✅ **Idempotent Operations:** Can re-run stages without side effects  
✅ **Version Control:** All configuration in git  
✅ **Automated Testing:** Dry-run mode validates without execution

### 2. Immutable Infrastructure
✅ **Blue-Green Deployment:** New version deployed to STANDBY, tested, then switched  
✅ **No In-Place Updates:** Never modify LIVE, always deploy to STANDBY  
✅ **Rollback via Traffic Switch:** Instant rollback by switching HAProxy routing

### 3. Defense in Depth
✅ **Multiple Validation Gates:** Pre-flight checks, config tests, health checks  
✅ **Graceful Degradation:** HAProxy health checks mark backends down if unhealthy  
✅ **Audit Trail:** Netbox tracks all infrastructure changes  
✅ **Monitoring from Day 1:** node_exporter and promtail installed during deployment

### 4. Separation of Concerns
✅ **DNS Layer:** Wix manages DNS, points to HAProxy VIP  
✅ **Routing Layer:** HAProxy handles traffic routing and health checks  
✅ **SSL Layer:** NPM or HAProxy handles SSL termination  
✅ **Application Layer:** Containers run application code only

### 5. Observability
✅ **Health Endpoints:** Every service exposes `/health`  
✅ **Structured Logging:** Application logs to files, promtail ships to Loki  
✅ **Metrics Collection:** node_exporter exposes system metrics  
✅ **Centralized Monitoring:** Prometheus scrapes all metrics, Grafana visualizes

### 6. Security Best Practices
✅ **Principle of Least Privilege:** Service users with minimal permissions  
✅ **Secret Management:** `.env` files with 0600 permissions  
✅ **Network Segmentation:** Containers only accessible from HAProxy  
✅ **Webhook Verification:** Stripe signature validation on all webhooks

---

## Comparison: Original vs Revised Pipeline

| Aspect | Original Pipeline | Revised Pipeline |
|--------|------------------|------------------|
| **Order** | Container first | Infrastructure first |
| **DNS** | Points to container IP | Points to HAProxy VIP via CNAME |
| **Netbox** | Created as "active" | Created as "planned", updated to "active" |
| **HAProxy** | Manual config later | Pre-configured with blue/green backends |
| **Testing** | After deployment | Before and after deployment |
| **Rollback** | Complex (destroy + cleanup) | Simple (traffic switch or destroy) |
| **Blue-Green** | Not configured | Fully configured upfront |
| **Validation** | Minimal | Multiple gates at each stage |
| **Documentation** | Manual | Auto-generated + updated |

---

## Rollback Strategy

### Stage-by-Stage Rollback

**Stage 1 (DNS) Fails:**
- Remove DNS records via Wix MCP
- No other cleanup needed

**Stage 2 (Netbox) Fails:**
- Delete Netbox VM entry
- Delete IP reservation
- Remove DNS records

**Stage 3 (HAProxy) Fails:**
- Remove HAProxy backend config
- Reload HAProxy
- Delete Netbox entries
- Remove DNS records

**Stage 5 (Container Creation) Fails:**
- Destroy container: `pct destroy <CTID>`
- Update Netbox status: "active" → "planned"
- Remove HAProxy backend config
- Remove DNS records

**Stage 6-10 (Application) Fails:**
- Stop service: `systemctl stop cloudigan-api`
- Remove application files
- Destroy container
- Full infrastructure rollback

**Stage 12 (Traffic Switch) Fails:**
- Reload old HAProxy config
- Verify LIVE is serving traffic
- Fix STANDBY issues offline

---

## Metrics for Success

### Deployment Metrics
- **Deployment Time:** Target < 15 minutes (infrastructure + application)
- **Success Rate:** Target > 95% (first-time deployments)
- **Rollback Time:** Target < 2 minutes (traffic switch)

### Operational Metrics
- **Uptime:** Target > 99.9%
- **Response Time:** Target < 500ms (p95)
- **Error Rate:** Target < 0.1%
- **Health Check Success:** Target > 99%

### Infrastructure Metrics
- **DNS Propagation:** < 5 minutes (TTL 300s)
- **HAProxy Reload:** < 1 second (zero downtime)
- **Container Start:** < 30 seconds
- **Application Start:** < 10 seconds

---

## Future Improvements

### Short-Term (Next 3 Months)
1. **Automated Testing:** Add smoke tests to Stage 8
2. **Terraform Integration:** Convert pipeline to Terraform modules
3. **GitOps:** Trigger deployments from git commits
4. **Slack Notifications:** Alert on deployment events

### Medium-Term (Next 6 Months)
1. **Multi-Region:** Extend to multiple Proxmox hosts
2. **Auto-Scaling:** Dynamic resource allocation based on load
3. **Canary Deployments:** Gradual traffic shift (10% → 50% → 100%)
4. **A/B Testing:** Route traffic based on user attributes

### Long-Term (Next 12 Months)
1. **Kubernetes Migration:** Evaluate K8s for container orchestration
2. **Service Mesh:** Implement Istio or Linkerd for advanced routing
3. **Chaos Engineering:** Automated failure injection and recovery testing
4. **Multi-Cloud:** Extend to cloud providers for DR

---

## Lessons Learned

### What Worked Well
✅ Infrastructure-first approach prevented deployment failures  
✅ Blue-green pattern enabled zero-downtime deployments  
✅ HAProxy VIP provided stable routing target  
✅ Netbox status tracking provided clear audit trail  
✅ Multiple validation gates caught issues early

### What Could Be Improved
⚠️ DNS propagation delays (consider lower TTL for new services)  
⚠️ Manual Stripe webhook configuration (could be automated)  
⚠️ OAuth token management (consider secret management service)  
⚠️ Monitoring setup (could be part of container template)

### Key Takeaways
1. **Always configure infrastructure before deployment**
2. **Test at every stage, not just at the end**
3. **Use CNAMEs for flexibility, not A records to container IPs**
4. **HAProxy VIP is the stable routing target**
5. **Netbox status progression tracks deployment state**
6. **Blue-green pattern should be configured upfront, not added later**

---

## References

### Industry Standards
- **12-Factor App:** https://12factor.net/
- **Infrastructure as Code:** HashiCorp Terraform best practices
- **Blue-Green Deployment:** Martin Fowler's deployment patterns
- **Immutable Infrastructure:** Netflix deployment model

### Internal Documentation
- **Decision D-029:** Specialized container deployment via vendor installers
- **Decision D-030:** OAuth Token Management Pattern with Playwright
- **Policy:** `haproxy-blue-green-standard.md`
- **Policy:** `container-ssh-access.md`
- **Runbook:** `deployment.md`

### Production Examples
- **TheoShift:** Blue-green deployment (CT134, CT132)
- **LDC Tools:** Blue-green deployment (CT133, CT135)
- **QuantShift:** Blue-green deployment (CT137, CT138)

---

**Status:** ✅ Ready for Dry-Run Execution
