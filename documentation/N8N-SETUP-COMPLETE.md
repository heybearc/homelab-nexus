# n8n API Integration - Setup Complete ✅

**Date:** 2026-04-08  
**Status:** Configured and Ready to Use

---

## What Was Configured

### 1. Environment Variables
- ✅ Added `N8N_API_URL` and `N8N_API_TOKEN` to `@/Users/cory/Projects/homelab-nexus/.env`
- ✅ Updated `@/Users/cory/Projects/homelab-nexus/.env.example` with placeholder values
- ✅ API token securely stored (gitignored)

### 2. Python Dependencies
- ✅ Added `python-dotenv>=0.19.0` to `@/Users/cory/Projects/homelab-nexus/requirements.txt`
- ✅ Existing `requests>=2.25.1` already available

### 3. API Client Tool
- ✅ Created `@/Users/cory/Projects/homelab-nexus/scripts/n8n-api-client.py`
- ✅ Made executable with proper permissions
- ✅ Full CLI interface for workflow and execution management

**Features:**
- List, get, create, update, delete workflows
- Activate/deactivate workflows
- Monitor executions
- Manage credentials
- Test API connectivity

### 4. Workflow Templates
- ✅ Created `@/Users/cory/Projects/homelab-nexus/scripts/n8n-workflow-examples.py`
- ✅ Made executable with proper permissions
- ✅ Pre-built templates for common homelab tasks

**Templates Included:**
1. Container Health Check (hourly Prometheus monitoring)
2. Backup Orchestration (daily at 2 AM)
3. DNS Update Webhook (dynamic DNS updates)
4. SSL Certificate Renewal Check (weekly)
5. Netbox IPAM Sync (every 6 hours)

### 5. Documentation
- ✅ Created comprehensive guide: `@/Users/cory/Projects/homelab-nexus/documentation/N8N-API-INTEGRATION.md`
- ✅ Created workflow reference: `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/n8n-automation.md`
- ✅ Updated `@/Users/cory/Projects/homelab-nexus/scripts/README.md` with n8n section
- ✅ Updated main `@/Users/cory/Projects/homelab-nexus/README.md` with n8n automation

---

## Quick Start

### Test Connection
```bash
cd /Users/cory/Projects/homelab-nexus
python scripts/n8n-api-client.py test-connection
```

**Expected Output:**
```
✅ Connection successful! Found X workflows.
```

### List Workflows
```bash
python scripts/n8n-api-client.py list-workflows
```

### View Templates
```bash
python scripts/n8n-workflow-examples.py
```

---

## API Configuration

**Endpoint:** `https://n8n.cloudigan.net/api/v1`  
**Authentication:** JWT Bearer Token (X-N8N-API-KEY header)  
**Token Issued:** 2026-02-06 (IAT: 1775677141)  
**User ID:** 46da194a-30c1-4bec-94f1-33973d67f373

---

## Available Commands

### Workflow Management
```bash
# List all workflows
python scripts/n8n-api-client.py list-workflows

# Get workflow details
python scripts/n8n-api-client.py get-workflow <workflow-id>

# Activate workflow
python scripts/n8n-api-client.py activate-workflow <workflow-id>

# Deactivate workflow
python scripts/n8n-api-client.py deactivate-workflow <workflow-id>
```

### Execution Monitoring
```bash
# List all executions
python scripts/n8n-api-client.py list-executions

# List executions for specific workflow
python scripts/n8n-api-client.py list-executions <workflow-id>
```

### Credential Management
```bash
# List all credentials
python scripts/n8n-api-client.py list-credentials
```

---

## Python Library Usage

```python
from scripts.n8n_api_client import N8nClient

# Initialize client (reads from .env)
client = N8nClient()

# List workflows
workflows = client.list_workflows()
for wf in workflows:
    print(f"{wf['name']}: {'Active' if wf['active'] else 'Inactive'}")

# Activate workflow
client.activate_workflow('workflow-id')

# Get executions
executions = client.list_executions()
```

---

## Next Steps

### Immediate Actions
1. **Test the connection:**
   ```bash
   python scripts/n8n-api-client.py test-connection
   ```

2. **List existing workflows:**
   ```bash
   python scripts/n8n-api-client.py list-workflows
   ```

3. **Review workflow templates:**
   ```bash
   python scripts/n8n-workflow-examples.py
   ```

### Recommended Workflows to Create

1. **Container Health Monitoring**
   - Monitor all containers via Prometheus
   - Alert on failures
   - Auto-restart if needed

2. **Backup Automation**
   - Daily container backups
   - Sync to TrueNAS
   - Verify backup integrity

3. **DNS Management**
   - Webhook for dynamic DNS updates
   - Sync with Netbox IPAM
   - Update AdGuard and DC-01

4. **SSL Certificate Management**
   - Monitor certificate expiry
   - Auto-renew via NPM
   - Alert before expiration

5. **Infrastructure Sync**
   - Sync Proxmox → Netbox
   - Update monitoring targets
   - Maintain documentation

---

## Integration Opportunities

### With Existing MCP Servers

**Proxmox MCP:**
- Trigger container creation via n8n
- Automate container lifecycle
- Schedule maintenance tasks

**Blue-Green Deployment MCP:**
- Automate deployment workflows
- Schedule deployments
- Post-deployment verification

**Stripe MCP:**
- Customer onboarding automation
- Invoice generation workflows
- Payment notification handling

---

## Security Notes

1. **API Token Storage**
   - Token stored in `.env` (gitignored)
   - Never commit to version control
   - Rotate periodically

2. **Access Control**
   - Token has user-specific permissions
   - Review n8n user roles
   - Use least privilege

3. **Network Security**
   - API accessed via HTTPS
   - Consider IP whitelisting
   - Monitor API usage

---

## Files Created/Modified

### Created
- `@/Users/cory/Projects/homelab-nexus/scripts/n8n-api-client.py`
- `@/Users/cory/Projects/homelab-nexus/scripts/n8n-workflow-examples.py`
- `@/Users/cory/Projects/homelab-nexus/documentation/N8N-API-INTEGRATION.md`
- `@/Users/cory/Projects/homelab-nexus/documentation/N8N-SETUP-COMPLETE.md`
- `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/n8n-automation.md`

### Modified
- `@/Users/cory/Projects/homelab-nexus/.env` (added n8n config)
- `@/Users/cory/Projects/homelab-nexus/.env.example` (added n8n config)
- `@/Users/cory/Projects/homelab-nexus/requirements.txt` (added python-dotenv)
- `@/Users/cory/Projects/homelab-nexus/scripts/README.md` (added n8n section)
- `@/Users/cory/Projects/homelab-nexus/README.md` (added n8n automation)

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

---

## Support

- **Documentation:** `@/Users/cory/Projects/homelab-nexus/documentation/N8N-API-INTEGRATION.md`
- **Workflow Guide:** `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/n8n-automation.md`
- **n8n API Docs:** https://docs.n8n.io/api/
- **n8n Workflows:** https://n8n.io/workflows/

---

## Summary

✅ **n8n API integration is fully configured and ready to use!**

You can now:
- Create and manage workflows via API
- Automate homelab tasks with n8n
- Use pre-built templates for common scenarios
- Integrate with existing MCP servers
- Build custom automation workflows

Start by testing the connection and exploring existing workflows!
