# Promote to Control Plane

Items ready to promote from homelab-nexus to Cloudy-Work control plane.

---

## Infrastructure: Cloudigan API Blue-Green MCP Integration
**Type:** infrastructure
**Target:** _cloudy-ops/docs/infrastructure/mcp-server-apps.md
**Date:** 2026-03-17

**Summary:** Add cloudigan-api to homelab blue-green MCP server for automated deployment management

**Details:**
Add cloudigan-api configuration to the homelab MCP server apps dictionary:

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

**Current Status:**
- Blue (LIVE): CT181 @ 10.92.3.181 - Production traffic
- Green (STANDBY): CT182 @ 10.92.3.182 - M365 OAuth2 email ready
- HAProxy configured with both backends
- Service tested and healthy on both containers

**Impact:** Enables automated blue-green deployment management for cloudigan-api using MCP commands

**References:** See control-plane-promotions/cloudigan-api-mcp-integration.md for complete details

---

## Promotion History

**2026-03-16:** D-029 - Specialized container deployment via vendor installers → DECISIONS.md ✓
