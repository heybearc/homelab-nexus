# Add Cloudigan API to Homelab Blue-Green MCP

## Current Status
The homelab MCP server currently manages:
- theoshift (CT134 blue, CT132 green)
- ldc-tools
- quantshift
- bni-chapter-toolkit (sandbox)

**Cloudigan API needs to be added** with:
- Blue (LIVE): CT181 @ 10.92.3.181
- Green (STANDBY): CT182 @ 10.92.3.182
- HAProxy VIP: 10.92.3.33
- Service: cloudigan-api.service

## Configuration Required

The homelab MCP server needs to be updated to include cloudigan-api configuration:

```python
# In the MCP server configuration
APPS = {
    'theoshift': {
        'blue': {'ctid': 134, 'ip': '10.92.3.24'},
        'green': {'ctid': 132, 'ip': '10.92.3.22'},
        'haproxy_backend': 'theoshift',
        'service': 'theoshift.service'
    },
    'cloudigan-api': {
        'blue': {'ctid': 181, 'ip': '10.92.3.181'},
        'green': {'ctid': 182, 'ip': '10.92.3.182'},
        'haproxy_backend': 'cloudigan_api',
        'haproxy_vip': '10.92.3.33',
        'service': 'cloudigan-api.service',
        'health_endpoint': '/health',
        'port': 3000
    }
}
```

## Steps to Add

1. **Locate the homelab MCP server source:**
   - Path: `/Users/cory/Projects/Cloudy-Work/shared/mcp-servers/homelab-blue-green-mcp/`
   - Or wherever the MCP server is deployed

2. **Update the app configuration file**
   - Add cloudigan-api to the apps list
   - Configure blue/green container IDs and IPs
   - Set HAProxy backend name

3. **Restart the MCP server**
   - Reload configuration
   - Test with `mcp0_get_deployment_status` for cloudigan-api

4. **Verify MCP integration**
   - Check deployment status
   - Test traffic switching
   - Verify health checks

## Once Integrated

You'll be able to use MCP commands:
```
mcp0_get_deployment_status(app='cloudigan-api')
mcp0_deploy_to_standby(app='cloudigan-api')
mcp0_switch_traffic(app='cloudigan-api')
```

## Current Workaround

Until MCP integration is complete, use manual HAProxy commands:
```bash
ssh root@10.92.3.33
vi /etc/haproxy/haproxy.cfg
# Change: use_backend cloudigan_api_blue if is_cloudigan_api
# To:     use_backend cloudigan_api_green if is_cloudigan_api
systemctl reload haproxy
```
