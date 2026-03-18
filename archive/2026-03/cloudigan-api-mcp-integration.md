# Control Plane Promotion: Cloudigan API MCP Integration

**Date:** 2026-03-17  
**Type:** MCP Server Configuration Update  
**Priority:** High  
**Status:** Ready for Promotion

---

## Summary

Add cloudigan-api blue-green deployment management to the homelab MCP server, enabling automated traffic switching and deployment management alongside existing apps (theoshift, ldc-tools, quantshift).

---

## Changes Required

### 1. MCP Server Configuration Update

**File:** `homelab-blue-green-mcp/apps_config.py` (or equivalent)

**Add to APPS dictionary:**

```python
'cloudigan-api': {
    'name': 'Cloudigan API',
    'description': 'Stripe webhook to Datto RMM integration',
    'blue': {
        'ctid': 181,
        'ip': '10.92.3.181',
        'hostname': 'cloudigan-api-blue',
        'node': 'pve'
    },
    'green': {
        'ctid': 182,
        'ip': '10.92.3.182',
        'hostname': 'cloudigan-api-green',
        'node': 'pve'
    },
    'haproxy': {
        'vip': '10.92.3.33',
        'backend_blue': 'cloudigan_api_blue',
        'backend_green': 'cloudigan_api_green',
        'config_path': '/etc/haproxy/haproxy.cfg',
        'acl_name': 'is_cloudigan_api',
        'use_backend_line': 'use_backend cloudigan_api_blue if is_cloudigan_api'
    },
    'service': {
        'name': 'cloudigan-api.service',
        'port': 3000,
        'health_endpoint': '/health',
        'health_check_timeout': 5
    },
    'monitoring': {
        'enabled': True,
        'check_interval': 30,
        'alert_on_failure': True
    },
    'deployment': {
        'requires_approval': True,
        'backup_before_switch': True,
        'rollback_on_failure': True
    }
}
```

---

## Infrastructure Details

### Containers

**Blue (LIVE) - CT181:**
- IP: 10.92.3.181
- Hostname: cloudigan-api-blue
- Status: Running
- Current: Production traffic

**Green (STANDBY) - CT182:**
- IP: 10.92.3.182
- Hostname: cloudigan-api-green
- Status: Running
- Updates: M365 OAuth2 email integration complete

### HAProxy Configuration

**VIP:** 10.92.3.33  
**Config:** `/etc/haproxy/haproxy.cfg`

**Current routing:**
```
use_backend cloudigan_api_blue if is_cloudigan_api
```

**Backends:**
- `cloudigan_api_blue` → 10.92.3.181:3000
- `cloudigan_api_green` → 10.92.3.182:3000

### Service Details

**Service:** cloudigan-api.service  
**Port:** 3000  
**Health Check:** GET /health  
**Expected Response:** `{"status":"ok"}`

---

## Testing Completed

✅ **STANDBY Container (CT182):**
- Service running and healthy
- M365 OAuth2 email tested successfully
- Health endpoint responding
- HAProxy green backend routing verified

✅ **Email Integration:**
- Azure AD app registered
- OAuth2 token refresh working
- Test email sent from noreply@cloudigan.com
- Email module integrated into webhook

✅ **Infrastructure:**
- Blue-green containers deployed
- HAProxy configured with both backends
- Network routing verified
- Service auto-start configured

---

## Post-Promotion Verification

After MCP integration is promoted to control plane:

1. **Test MCP Commands:**
   ```python
   # Check deployment status
   mcp0_get_deployment_status(app='cloudigan-api')
   
   # Should show:
   # - Blue (LIVE): CT181 @ 10.92.3.181
   # - Green (STANDBY): CT182 @ 10.92.3.182
   # - Both healthy
   ```

2. **Test Traffic Switch:**
   ```python
   # Switch traffic to green (with approval)
   mcp0_switch_traffic(app='cloudigan-api', requireApproval=True)
   
   # Should:
   # - Run health checks on green
   # - Update HAProxy config
   # - Reload HAProxy
   # - Verify traffic routing
   ```

3. **Verify Production:**
   - Test Stripe checkout flow
   - Verify email sent from noreply@cloudigan.com
   - Check Wix CMS integration
   - Verify Datto site creation

---

## Rollback Plan

If issues occur after traffic switch:

**Via MCP:**
```python
mcp0_switch_traffic(app='cloudigan-api', emergency=True)
```

**Manual (if MCP unavailable):**
```bash
ssh root@10.92.3.33
vi /etc/haproxy/haproxy.cfg
# Change back to: use_backend cloudigan_api_blue if is_cloudigan_api
systemctl reload haproxy
```

---

## Dependencies

- Homelab MCP server running
- Proxmox access for container management
- HAProxy VIP (10.92.3.33) accessible
- Both containers (CT181, CT182) operational

---

## Benefits

1. **Automated Management:**
   - Consistent deployment process
   - Automated health checks
   - Built-in rollback capability

2. **Zero Downtime:**
   - Traffic switch without service interruption
   - Health verification before switching
   - Automatic rollback on failure

3. **Monitoring:**
   - Integrated health monitoring
   - Deployment history tracking
   - Alert on failures

4. **Consistency:**
   - Same management interface as other apps
   - Standardized deployment workflow
   - Centralized control

---

## Files to Promote

1. **MCP Configuration:**
   - `apps_config.py` (or equivalent)
   - Add cloudigan-api to APPS dictionary

2. **Documentation:**
   - This promotion document
   - Update MCP server README with cloudigan-api

3. **Verification Scripts:**
   - Health check validation
   - Traffic switch testing

---

## Promotion Checklist

- [ ] Review configuration changes
- [ ] Backup current MCP server config
- [ ] Add cloudigan-api to APPS dictionary
- [ ] Restart MCP server
- [ ] Test `mcp0_get_deployment_status(app='cloudigan-api')`
- [ ] Verify health checks working
- [ ] Test traffic switch (dry run)
- [ ] Document in control plane

---

## Contact

**Owner:** Cory  
**System:** Cloudigan API  
**Environment:** Production  
**MCP Server:** homelab-blue-green-deployment

---

**Ready for promotion to control plane.**
