# API Integrations Summary

**Date:** 2026-04-08  
**Status:** ✅ All Configured

---

## Overview

This document summarizes all API integrations configured in the homelab-nexus repository.

---

## Configured APIs

### 1. n8n Automation Platform ✅

**Purpose:** Workflow automation and orchestration  
**Endpoint:** `https://n8n.cloudigan.net/api/v1`  
**Authentication:** JWT Bearer Token (X-N8N-API-KEY header)

**Client:** `@/Users/cory/Projects/homelab-nexus/scripts/n8n-api-client.py`  
**Documentation:** `@/Users/cory/Projects/homelab-nexus/documentation/N8N-API-INTEGRATION.md`  
**Workflow:** `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/n8n-automation.md`

**Quick Test:**
```bash
python scripts/n8n-api-client.py test-connection
```

**Capabilities:**
- Workflow management (create, update, activate, deactivate)
- Execution monitoring
- Credential management
- Pre-built workflow templates for homelab tasks

---

### 2. Vikunja Task Management ✅

**Purpose:** Project and task tracking  
**Endpoint:** `https://vikunja.cloudigan.net/api/v1`  
**Authentication:** Bearer Token (Authorization header)

**Client:** `@/Users/cory/Projects/homelab-nexus/scripts/vikunja-api-client.py`  
**Documentation:** `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-API-INTEGRATION.md`  
**Workflow:** `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/vikunja-tasks.md`

**Quick Test:**
```bash
python scripts/vikunja-api-client.py test-connection
```

**Capabilities:**
- Project management
- Task creation and tracking
- Label organization
- Search functionality
- Priority and due date management

---

### 3. LibreTranslate Translation ✅

**Purpose:** Multi-language text translation  
**Endpoint:** `https://libretranslate.cloudigan.net`  
**Authentication:** API Key (in request body)

**Client:** `@/Users/cory/Projects/homelab-nexus/scripts/libretranslate-api-client.py`  
**Documentation:** `@/Users/cory/Projects/homelab-nexus/documentation/LIBRETRANSLATE-API-INTEGRATION.md`

**Quick Test:**
```bash
python scripts/libretranslate-api-client.py test-connection
```

**Capabilities:**
- Translate text between 100+ languages
- Auto-detect source language
- Batch translation
- File translation
- Language detection

---

## Environment Configuration

All API credentials are stored in `@/Users/cory/Projects/homelab-nexus/.env`:

```bash
# n8n Automation Platform
N8N_API_URL=https://n8n.cloudigan.net/api/v1
N8N_API_TOKEN=<jwt-token>

# Vikunja Task Management
VIKUNJA_API_URL=https://vikunja.cloudigan.net/api/v1
VIKUNJA_API_TOKEN=tk_<token>

# LibreTranslate API
LIBRETRANSLATE_API_URL=https://libretranslate.cloudigan.net
LIBRETRANSLATE_API_KEY=<api-key>
```

**Security:**
- All tokens stored in `.env` (gitignored)
- Never committed to version control
- Template provided in `.env.example`

---

## Integration Opportunities

### n8n + Vikunja

**Automated Task Management:**
1. Create Vikunja tasks from n8n workflow failures
2. Auto-complete tasks when deployments succeed
3. Generate daily task summaries
4. Create tasks from monitoring alerts

**Example n8n → Vikunja Workflow:**
```javascript
// n8n HTTP Request to Vikunja
{
  "url": "https://vikunja.cloudigan.net/api/v1/projects/1/tasks",
  "method": "PUT",
  "headers": {
    "Authorization": "Bearer {{$env.VIKUNJA_API_TOKEN}}"
  },
  "body": {
    "title": "Workflow Failed: {{$workflow.name}}",
    "priority": 4
  }
}
```

### n8n + Homelab Infrastructure

**Automation Workflows:**
1. Container health monitoring
2. Backup orchestration
3. DNS updates via webhook
4. SSL certificate renewal checks
5. Netbox IPAM sync

### Vikunja + Homelab Operations

**Task Tracking:**
1. Infrastructure maintenance schedules
2. Deployment checklists
3. Issue tracking
4. Documentation tasks
5. Upgrade planning

### LibreTranslate + Documentation

**Multi-language Support:**
1. Translate README files
2. Internationalize error messages
3. Multi-language notifications
4. Translate log entries
5. Documentation localization

### Combined Integrations

**n8n + Vikunja + LibreTranslate:**
1. Create tasks in multiple languages
2. Translate workflow outputs
3. Multi-language alert notifications
4. Internationalized task descriptions

---

## Quick Reference

### Test All Connections
```bash
# n8n
python scripts/n8n-api-client.py test-connection

# Vikunja
python scripts/vikunja-api-client.py test-connection

# LibreTranslate
python scripts/libretranslate-api-client.py test-connection
```

### Common Operations

**n8n:**
```bash
# List workflows
python scripts/n8n-api-client.py list-workflows

# Activate workflow
python scripts/n8n-api-client.py activate-workflow <id>

# View templates
python scripts/n8n-workflow-examples.py
```

**Vikunja:**
```bash
# List projects
python scripts/vikunja-api-client.py list-projects

# List tasks
python scripts/vikunja-api-client.py list-tasks

# Create task
python scripts/vikunja-api-client.py create-task <project-id> "Task title"
```

**LibreTranslate:**
```bash
# List languages
python scripts/libretranslate-api-client.py languages

# Translate text
python scripts/libretranslate-api-client.py translate "Hello" en es

# Detect language
python scripts/libretranslate-api-client.py detect "Bonjour"
```

---

## Python Library Usage

### n8n Example
```python
from scripts.n8n_api_client import N8nClient

client = N8nClient()
workflows = client.list_workflows()
client.activate_workflow('workflow-id')
```

### Vikunja Example
```python
from scripts.vikunja_api_client import VikunjaClient

client = VikunjaClient()
projects = client.list_projects()
task = client.create_task(1, "Deploy CT200")
client.complete_task(task['id'])
```

### LibreTranslate Example
```python
from scripts.libretranslate_api_client import LibreTranslateClient

client = LibreTranslateClient()
result = client.translate("Hello world", "en", "es")
print(result['translatedText'])  # "Hola mundo"
```

---

## Files Created

### Scripts
- `@/Users/cory/Projects/homelab-nexus/scripts/n8n-api-client.py`
- `@/Users/cory/Projects/homelab-nexus/scripts/n8n-workflow-examples.py`
- `@/Users/cory/Projects/homelab-nexus/scripts/vikunja-api-client.py`
- `@/Users/cory/Projects/homelab-nexus/scripts/libretranslate-api-client.py`

### Documentation
- `@/Users/cory/Projects/homelab-nexus/documentation/N8N-API-INTEGRATION.md`
- `@/Users/cory/Projects/homelab-nexus/documentation/N8N-SETUP-COMPLETE.md`
- `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-API-INTEGRATION.md`
- `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-SETUP-COMPLETE.md`
- `@/Users/cory/Projects/homelab-nexus/documentation/LIBRETRANSLATE-API-INTEGRATION.md`
- `@/Users/cory/Projects/homelab-nexus/documentation/API-INTEGRATIONS-SUMMARY.md`

### Workflows
- `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/n8n-automation.md`
- `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/vikunja-tasks.md`

### Configuration
- `@/Users/cory/Projects/homelab-nexus/.env` (updated)
- `@/Users/cory/Projects/homelab-nexus/.env.example` (updated)
- `@/Users/cory/Projects/homelab-nexus/requirements.txt` (updated)

### README Updates
- `@/Users/cory/Projects/homelab-nexus/README.md` (updated)
- `@/Users/cory/Projects/homelab-nexus/scripts/README.md` (updated)

---

## Next Steps

1. **Test Connections**
   ```bash
   python scripts/n8n-api-client.py test-connection
   python scripts/vikunja-api-client.py test-connection
   ```

2. **Explore n8n Workflows**
   ```bash
   python scripts/n8n-api-client.py list-workflows
   python scripts/n8n-workflow-examples.py
   ```

3. **Set Up Vikunja Projects**
   ```bash
   python scripts/vikunja-api-client.py create-project "Homelab Infrastructure"
   python scripts/vikunja-api-client.py list-projects
   ```

4. **Create Integration Workflows**
   - n8n workflow to create Vikunja tasks
   - Monitoring alerts → Vikunja tasks
   - Deployment automation with task tracking

---

## Support & Documentation

- **n8n API Docs:** https://docs.n8n.io/api/
- **Vikunja API Docs:** https://vikunja.io/docs/api-documentation/
- **Local Docs:** See individual integration documentation files

---

## Summary

✅ **All three API integrations are fully configured and ready to use!**

You now have:
- **n8n** for workflow automation and orchestration
- **Vikunja** for task and project management
- **LibreTranslate** for multi-language translation
- Python clients for all APIs
- CLI tools for common operations
- Integration opportunities between systems
- Comprehensive documentation

Start automating your homelab operations today! 🚀
