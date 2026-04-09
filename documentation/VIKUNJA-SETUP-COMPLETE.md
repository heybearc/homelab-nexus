# Vikunja API Integration - Setup Complete ✅

**Date:** 2026-04-08  
**Status:** Configured and Ready to Use

---

## What Was Configured

### 1. Environment Variables
- ✅ Added `VIKUNJA_API_URL` and `VIKUNJA_API_TOKEN` to `@/Users/cory/Projects/homelab-nexus/.env`
- ✅ Updated `@/Users/cory/Projects/homelab-nexus/.env.example` with placeholder values
- ✅ API token securely stored (gitignored)

### 2. API Client Tool
- ✅ Created `@/Users/cory/Projects/homelab-nexus/scripts/vikunja-api-client.py`
- ✅ Made executable with proper permissions
- ✅ Full CLI interface for project and task management

**Features:**
- List, get, create, update, delete projects
- List, get, create, update, delete, complete tasks
- Manage labels
- Search functionality
- User information
- Test API connectivity

### 3. Documentation
- ✅ Created comprehensive guide: `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-API-INTEGRATION.md`
- ✅ Created workflow reference: `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/vikunja-tasks.md`
- ✅ Updated `@/Users/cory/Projects/homelab-nexus/scripts/README.md` with Vikunja section
- ✅ Updated main `@/Users/cory/Projects/homelab-nexus/README.md` with Vikunja task management

---

## Quick Start

### Test Connection
```bash
cd /Users/cory/Projects/homelab-nexus
python scripts/vikunja-api-client.py test-connection
```

**Expected Output:**
```
✅ Connection successful!
   User: <username>
   Projects: X
```

### List Projects
```bash
python scripts/vikunja-api-client.py list-projects
```

### List Tasks
```bash
python scripts/vikunja-api-client.py list-tasks
```

---

## API Configuration

**Endpoint:** `https://vikunja.cloudigan.net/api/v1`  
**Authentication:** Bearer Token (Authorization header)  
**Token Format:** `tk_` prefix + 40 character hex string

---

## Available Commands

### Project Management
```bash
# List all projects
python scripts/vikunja-api-client.py list-projects

# Get project details
python scripts/vikunja-api-client.py get-project <project-id>

# Create project
python scripts/vikunja-api-client.py create-project "Project Name"
```

### Task Management
```bash
# List all tasks
python scripts/vikunja-api-client.py list-tasks

# List tasks in project
python scripts/vikunja-api-client.py list-tasks <project-id>

# Create task
python scripts/vikunja-api-client.py create-task <project-id> "Task title"

# Get task details
python scripts/vikunja-api-client.py get-task <task-id>

# Complete task
python scripts/vikunja-api-client.py complete-task <task-id>
```

### Search & Labels
```bash
# Search tasks and projects
python scripts/vikunja-api-client.py search "keyword"

# List labels
python scripts/vikunja-api-client.py list-labels
```

### User Info
```bash
python scripts/vikunja-api-client.py user-info
```

---

## Python Library Usage

```python
from scripts.vikunja_api_client import VikunjaClient

# Initialize client (reads from .env)
client = VikunjaClient()

# List projects
projects = client.list_projects()
for proj in projects:
    print(f"{proj['title']}: {proj['count']['tasks']} tasks")

# Create a task
task = client.create_task(
    project_id=1,
    title="Deploy new container",
    description="Deploy CT200 with monitoring",
    priority=3
)

# Complete task
client.complete_task(task['id'])
```

---

## Next Steps

### Immediate Actions
1. **Test the connection:**
   ```bash
   python scripts/vikunja-api-client.py test-connection
   ```

2. **List existing projects:**
   ```bash
   python scripts/vikunja-api-client.py list-projects
   ```

3. **Create a homelab project:**
   ```bash
   python scripts/vikunja-api-client.py create-project "Homelab Infrastructure"
   ```

### Recommended Setup

1. **Create Projects for Organization**
   - Homelab Infrastructure
   - Container Deployments
   - Maintenance Tasks
   - Documentation
   - Monitoring & Alerts

2. **Create Labels for Categorization**
   - infrastructure
   - deployment
   - maintenance
   - urgent
   - monitoring
   - backup

3. **Set Up Task Templates**
   - Container deployment checklist
   - Backup verification steps
   - Update procedures
   - Incident response

---

## Integration with n8n

### Automated Task Creation

Create n8n workflows to automatically manage Vikunja tasks:

**1. Create Task from Monitoring Alert**
```javascript
// n8n HTTP Request node
{
  "url": "https://vikunja.cloudigan.net/api/v1/projects/1/tasks",
  "method": "PUT",
  "headers": {
    "Authorization": "Bearer {{$env.VIKUNJA_API_TOKEN}}"
  },
  "body": {
    "title": "Alert: {{$json.alertname}}",
    "description": "{{$json.description}}",
    "priority": 4
  }
}
```

**2. Daily Task Summary**
- Trigger: Daily at 9 AM
- Get incomplete tasks from Vikunja
- Format summary
- Send via email/Slack

**3. Auto-Complete Tasks**
- Trigger: Deployment success webhook
- Find related task by name/label
- Mark as complete
- Add completion notes

---

## Use Cases

### 1. Infrastructure Maintenance Tracking
```bash
# Create maintenance project
python scripts/vikunja-api-client.py create-project "Monthly Maintenance"

# Add tasks
python scripts/vikunja-api-client.py create-task 1 "Update all containers"
python scripts/vikunja-api-client.py create-task 1 "Verify backups"
python scripts/vikunja-api-client.py create-task 1 "Check SSL certificates"
```

### 2. Deployment Tracking
```python
# Create deployment task
task = client.create_task(
    project_id=2,
    title="Deploy CT200 - New Service",
    description="Steps:\n1. Create container\n2. Configure DNS\n3. Setup monitoring",
    priority=3
)
```

### 3. Issue Tracking
```python
# Create issue from alert
issue = client.create_task(
    project_id=3,
    title="High CPU on CT150",
    description="Prometheus alert triggered at 2026-04-08 15:30",
    priority=5,
    labels=[1, 3]  # urgent, monitoring
)
```

---

## Files Created/Modified

### Created
- `@/Users/cory/Projects/homelab-nexus/scripts/vikunja-api-client.py`
- `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-API-INTEGRATION.md`
- `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-SETUP-COMPLETE.md`
- `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/vikunja-tasks.md`

### Modified
- `@/Users/cory/Projects/homelab-nexus/.env` (added Vikunja config)
- `@/Users/cory/Projects/homelab-nexus/.env.example` (added Vikunja config)
- `@/Users/cory/Projects/homelab-nexus/scripts/README.md` (added Vikunja section)
- `@/Users/cory/Projects/homelab-nexus/README.md` (added Vikunja task management)

---

## Task Properties Reference

### Priority Levels
- `0` - No priority (default)
- `1` - Low 🔵
- `2` - Medium 🟢
- `3` - High 🟡
- `4` - Urgent 🟠
- `5` - Critical 🔴

### Common Task Fields
```python
{
    "title": "Task title",              # Required
    "description": "Task description",
    "done": False,                       # Boolean
    "priority": 3,                       # 0-5
    "due_date": "2026-04-15T00:00:00Z", # ISO 8601
    "labels": [1, 2],                    # Label IDs
    "percent_done": 50                   # 0-100
}
```

---

## Troubleshooting

### Connection Issues
```bash
# Test API connectivity
curl -H "Authorization: Bearer $VIKUNJA_API_TOKEN" \
     https://vikunja.cloudigan.net/api/v1/user

# Check environment variables
python -c "import os; from dotenv import load_dotenv; load_dotenv(); print(os.getenv('VIKUNJA_API_URL'))"
```

### Common Errors

**401 Unauthorized:**
- Check API token is correct
- Verify token hasn't been revoked
- Ensure `Authorization: Bearer` header is set

**404 Not Found:**
- Verify API URL is correct
- Check project/task ID exists
- Ensure endpoint path is correct

**403 Forbidden:**
- Check user permissions
- Verify project access rights
- Review sharing settings

---

## Support

- **Documentation:** `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-API-INTEGRATION.md`
- **Workflow Guide:** `@/Users/cory/Projects/homelab-nexus/.windsurf/workflows/vikunja-tasks.md`
- **Vikunja API Docs:** https://vikunja.io/docs/api-documentation/
- **Vikunja Features:** https://vikunja.io/features/

---

## Summary

✅ **Vikunja API integration is fully configured and ready to use!**

You can now:
- Create and manage projects via API
- Track tasks and to-dos programmatically
- Integrate with n8n for automated task management
- Search and organize tasks with labels
- Build custom task workflows for homelab operations

Start by testing the connection and creating your first project!
