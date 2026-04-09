# n8n API Integration

**Status:** ✅ Configured  
**Date:** 2026-04-08  
**API Version:** v1

---

## Overview

This document describes the n8n API integration for homelab automation. The n8n platform provides workflow automation capabilities accessible via REST API.

---

## Configuration

### Environment Variables

The following environment variables are configured in `.env`:

```bash
N8N_API_URL=https://n8n.cloudigan.net/api/v1
N8N_API_TOKEN=<JWT token>
```

**Security Notes:**
- API token is a JWT with user-specific claims
- Token is stored in `.env` (gitignored)
- Never commit the actual token to version control
- Token issued: 2026-02-06 (IAT: 1775677141)

---

## API Client

### Python Client

A Python client is available at `@/Users/cory/Projects/homelab-nexus/scripts/n8n-api-client.py`

**Features:**
- Workflow management (list, get, create, update, delete)
- Workflow activation/deactivation
- Execution monitoring
- Credential management
- CLI interface for common operations

### Installation

```bash
cd /Users/cory/Projects/homelab-nexus
pip install -r requirements.txt
```

### Usage Examples

**Test connection:**
```bash
python scripts/n8n-api-client.py test-connection
```

**List all workflows:**
```bash
python scripts/n8n-api-client.py list-workflows
```

**Get workflow details:**
```bash
python scripts/n8n-api-client.py get-workflow <workflow-id>
```

**Activate/deactivate workflow:**
```bash
python scripts/n8n-api-client.py activate-workflow <workflow-id>
python scripts/n8n-api-client.py deactivate-workflow <workflow-id>
```

**List executions:**
```bash
python scripts/n8n-api-client.py list-executions
python scripts/n8n-api-client.py list-executions <workflow-id>
```

**List credentials:**
```bash
python scripts/n8n-api-client.py list-credentials
```

---

## API Reference

### Authentication

All API requests require the `X-N8N-API-KEY` header:

```bash
curl -H "X-N8N-API-KEY: <token>" \
     https://n8n.cloudigan.net/api/v1/workflows
```

### Endpoints

#### Workflows

- `GET /workflows` - List all workflows
- `GET /workflows/{id}` - Get workflow details
- `POST /workflows` - Create workflow
- `PUT /workflows/{id}` - Update workflow
- `DELETE /workflows/{id}` - Delete workflow
- `POST /workflows/{id}/activate` - Activate workflow
- `POST /workflows/{id}/deactivate` - Deactivate workflow

#### Executions

- `GET /executions` - List executions
- `GET /executions?workflowId={id}` - List executions for workflow
- `GET /executions/{id}` - Get execution details
- `DELETE /executions/{id}` - Delete execution

#### Credentials

- `GET /credentials` - List credentials
- `GET /credentials/{id}` - Get credential
- `POST /credentials` - Create credential
- `PUT /credentials/{id}` - Update credential
- `DELETE /credentials/{id}` - Delete credential

---

## Use Cases

### Homelab Automation

**Potential n8n workflows for homelab:**

1. **Container Provisioning**
   - Trigger: Webhook or schedule
   - Actions: Call Proxmox API, update Netbox, configure DNS

2. **Monitoring Alerts**
   - Trigger: Prometheus webhook
   - Actions: Send notifications, create tickets, auto-remediation

3. **Backup Orchestration**
   - Trigger: Schedule
   - Actions: Backup containers, sync to TrueNAS, verify integrity

4. **User Onboarding** (MSP Platform)
   - Trigger: New customer signup
   - Actions: Create accounts in Plane, Twenty, Zammad, etc.

5. **SSL Certificate Renewal**
   - Trigger: Certificate expiry check
   - Actions: Renew via NPM, update DNS, verify deployment

6. **Infrastructure Health Checks**
   - Trigger: Schedule
   - Actions: Check services, verify DNS, test connectivity

---

## Integration with Existing Tools

### Proxmox
- Use n8n HTTP Request node with Proxmox API
- Automate container creation, snapshots, backups

### Netbox
- Update IPAM records automatically
- Sync infrastructure inventory

### Nginx Proxy Manager
- Create/update proxy hosts
- Manage SSL certificates

### AdGuard Home
- Update DNS rewrites
- Manage filtering rules

### Prometheus/Grafana
- Process alerts
- Create dashboards programmatically

---

## Python Library Usage

### Basic Example

```python
from scripts.n8n_api_client import N8nClient

# Initialize client (reads from .env)
client = N8nClient()

# List workflows
workflows = client.list_workflows()
for wf in workflows:
    print(f"{wf['name']}: {'Active' if wf['active'] else 'Inactive'}")

# Get specific workflow
workflow = client.get_workflow('workflow-id')
print(workflow)

# Activate workflow
client.activate_workflow('workflow-id')
```

### Advanced Example

```python
# Create a new workflow
workflow_data = {
    "name": "Container Health Check",
    "nodes": [
        {
            "name": "Schedule Trigger",
            "type": "n8n-nodes-base.scheduleTrigger",
            "position": [250, 300],
            "parameters": {
                "rule": {
                    "interval": [{"field": "hours", "hoursInterval": 1}]
                }
            }
        },
        {
            "name": "HTTP Request",
            "type": "n8n-nodes-base.httpRequest",
            "position": [450, 300],
            "parameters": {
                "url": "http://10.92.3.15:9100/metrics",
                "method": "GET"
            }
        }
    ],
    "connections": {
        "Schedule Trigger": {
            "main": [[{"node": "HTTP Request", "type": "main", "index": 0}]]
        }
    }
}

new_workflow = client.create_workflow(workflow_data)
print(f"Created workflow: {new_workflow['id']}")
```

---

## Security Considerations

1. **API Token Storage**
   - Stored in `.env` (gitignored)
   - Never commit to version control
   - Rotate periodically

2. **Access Control**
   - Token has user-specific permissions
   - Review n8n user roles and permissions
   - Use least privilege principle

3. **Network Security**
   - API accessed via HTTPS
   - Consider IP whitelisting if needed
   - Monitor API usage logs

4. **Credential Management**
   - n8n credentials stored encrypted
   - Use n8n's credential system for sensitive data
   - Don't hardcode credentials in workflows

---

## Troubleshooting

### Connection Issues

```bash
# Test API connectivity
curl -H "X-N8N-API-KEY: $N8N_API_TOKEN" \
     https://n8n.cloudigan.net/api/v1/workflows

# Check environment variables
python -c "import os; from dotenv import load_dotenv; load_dotenv(); print(os.getenv('N8N_API_URL'))"
```

### Common Errors

**401 Unauthorized:**
- Check API token is correct
- Verify token hasn't expired
- Ensure `X-N8N-API-KEY` header is set

**404 Not Found:**
- Verify API URL is correct
- Check endpoint path
- Ensure workflow/execution ID exists

**500 Internal Server Error:**
- Check n8n server logs
- Verify workflow JSON is valid
- Check for missing required fields

---

## Next Steps

- [ ] Create example workflows for common homelab tasks
- [ ] Integrate with Proxmox MCP server
- [ ] Set up monitoring alert workflows
- [ ] Create backup orchestration workflow
- [ ] Document workflow best practices
- [ ] Set up workflow version control (export/import)

---

## References

- **n8n API Documentation:** https://docs.n8n.io/api/
- **n8n Workflow Examples:** https://n8n.io/workflows/
- **JWT Token Info:** Issued 2026-02-06, User ID: 46da194a-30c1-4bec-94f1-33973d67f373

---

## Related Documentation

- `@/Users/cory/Projects/homelab-nexus/documentation/MSP-PLATFORM-ANALYSIS.md` - n8n in MSP platform
- `@/Users/cory/Projects/homelab-nexus/documentation/MSP-PLATFORM-SSO-COMPATIBILITY.md` - n8n SSO setup
- `@/Users/cory/Projects/homelab-nexus/scripts/n8n-api-client.py` - Python client implementation
