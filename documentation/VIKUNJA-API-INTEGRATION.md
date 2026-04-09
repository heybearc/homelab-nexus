# Vikunja API Integration

**Status:** ✅ Configured  
**Date:** 2026-04-08  
**API Version:** v1

---

## Overview

This document describes the Vikunja API integration for task and project management. Vikunja is an open-source to-do list application that provides comprehensive task management capabilities via REST API.

---

## Configuration

### Environment Variables

The following environment variables are configured in `.env`:

```bash
VIKUNJA_API_URL=https://vikunja.cloudigan.net/api/v1
VIKUNJA_API_TOKEN=tk_68cc3c64ddf9f5a9cfe5f35336fbaf024fb0b151
```

**Security Notes:**
- API token is a bearer token with user-specific permissions
- Token is stored in `.env` (gitignored)
- Never commit the actual token to version control
- Token format: `tk_` prefix followed by hex string

---

## API Client

### Python Client

A Python client is available at `@/Users/cory/Projects/homelab-nexus/scripts/vikunja-api-client.py`

**Features:**
- Project management (list, get, create, update, delete)
- Task management (list, get, create, update, delete, complete)
- Label management (list, create, update, delete)
- Search functionality
- User information
- CLI interface for common operations

### Installation

```bash
cd /Users/cory/Projects/homelab-nexus
pip install -r requirements.txt
```

### Usage Examples

**Test connection:**
```bash
python scripts/vikunja-api-client.py test-connection
```

**List all projects:**
```bash
python scripts/vikunja-api-client.py list-projects
```

**Create a project:**
```bash
python scripts/vikunja-api-client.py create-project "Homelab Infrastructure"
```

**List tasks:**
```bash
# All tasks
python scripts/vikunja-api-client.py list-tasks

# Tasks in specific project
python scripts/vikunja-api-client.py list-tasks <project-id>
```

**Create a task:**
```bash
python scripts/vikunja-api-client.py create-task <project-id> "Deploy new container"
```

**Complete a task:**
```bash
python scripts/vikunja-api-client.py complete-task <task-id>
```

**Search:**
```bash
python scripts/vikunja-api-client.py search "backup"
```

**List labels:**
```bash
python scripts/vikunja-api-client.py list-labels
```

---

## API Reference

### Authentication

All API requests require the `Authorization` header with Bearer token:

```bash
curl -H "Authorization: Bearer tk_..." \
     https://vikunja.cloudigan.net/api/v1/projects
```

### Endpoints

#### Projects

- `GET /projects` - List all projects
- `GET /projects/{id}` - Get project details
- `PUT /projects` - Create project
- `POST /projects/{id}` - Update project
- `DELETE /projects/{id}` - Delete project

#### Tasks

- `GET /tasks/all` - List all tasks
- `GET /projects/{id}/tasks` - List tasks in project
- `GET /tasks/{id}` - Get task details
- `PUT /projects/{id}/tasks` - Create task
- `POST /tasks/{id}` - Update task
- `DELETE /tasks/{id}` - Delete task

#### Labels

- `GET /labels` - List all labels
- `PUT /labels` - Create label
- `POST /labels/{id}` - Update label
- `DELETE /labels/{id}` - Delete label

#### User

- `GET /user` - Get current user information

#### Search

- `GET /search?s={query}` - Search tasks and projects

---

## Use Cases

### Homelab Task Management

**Potential Vikunja use cases:**

1. **Infrastructure Maintenance Tracking**
   - Track container updates
   - Schedule maintenance windows
   - Monitor backup tasks

2. **Project Planning**
   - Plan new service deployments
   - Track migration tasks
   - Organize upgrade schedules

3. **Issue Tracking**
   - Log infrastructure issues
   - Track bug fixes
   - Monitor service incidents

4. **Documentation Tasks**
   - Track documentation updates
   - Plan knowledge base articles
   - Organize runbook creation

5. **Automation Workflows**
   - Create tasks from monitoring alerts
   - Auto-generate tasks from n8n workflows
   - Sync with other project management tools

---

## Integration with n8n

### Automated Task Creation

Create n8n workflows to automatically create Vikunja tasks:

**Example: Create task from monitoring alert**
```json
{
  "nodes": [
    {
      "name": "Webhook Trigger",
      "type": "n8n-nodes-base.webhook"
    },
    {
      "name": "Create Vikunja Task",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "https://vikunja.cloudigan.net/api/v1/projects/1/tasks",
        "method": "PUT",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendBody": true,
        "bodyParameters": {
          "title": "={{$json.alert_name}}",
          "description": "={{$json.alert_description}}",
          "priority": 4
        }
      }
    }
  ]
}
```

**Example: Daily task summary**
- Trigger: Daily schedule
- Action: Get incomplete tasks
- Action: Send summary email/notification

---

## Python Library Usage

### Basic Example

```python
from scripts.vikunja_api_client import VikunjaClient

# Initialize client (reads from .env)
client = VikunjaClient()

# List projects
projects = client.list_projects()
for proj in projects:
    print(f"{proj['title']}: {proj['count']['tasks']} tasks")

# Get tasks
tasks = client.list_tasks()
for task in tasks:
    status = "✅" if task['done'] else "⬜"
    print(f"{status} {task['title']}")
```

### Advanced Example

```python
# Create a project for homelab tasks
project = client.create_project(
    title="Homelab Infrastructure",
    description="Infrastructure maintenance and deployment tasks"
)

# Create tasks
task1 = client.create_task(
    project_id=project['id'],
    title="Update Proxmox containers",
    description="Update all LXC containers to latest packages",
    priority=3,
    due_date="2026-04-15T00:00:00Z"
)

task2 = client.create_task(
    project_id=project['id'],
    title="Backup configuration files",
    priority=4
)

# Create labels
label = client.create_label(
    title="infrastructure",
    hex_color="#ff6b6b"
)

# Search tasks
results = client.search("backup")
print(f"Found {len(results['tasks'])} tasks matching 'backup'")

# Complete a task
client.complete_task(task1['id'])
```

---

## Task Properties

### Priority Levels
- `0` - No priority (default)
- `1` - Low (🔵)
- `2` - Medium (🟢)
- `3` - High (🟡)
- `4` - Urgent (🟠)
- `5` - Critical (🔴)

### Task Fields
- `title` - Task title (required)
- `description` - Task description
- `done` - Completion status (boolean)
- `priority` - Priority level (0-5)
- `due_date` - Due date (ISO 8601 format)
- `start_date` - Start date
- `end_date` - End date
- `labels` - Array of label IDs
- `assignees` - Array of user IDs
- `percent_done` - Completion percentage (0-100)

---

## Integration Opportunities

### With Existing Tools

**n8n Automation:**
- Create tasks from workflow executions
- Auto-complete tasks when workflows succeed
- Generate daily task reports

**Monitoring (Prometheus/Grafana):**
- Create tasks from alerts
- Track incident resolution
- Monitor SLA compliance

**Blue-Green Deployments:**
- Create deployment tasks
- Track rollback procedures
- Document deployment issues

**Container Management:**
- Track container updates
- Schedule maintenance windows
- Monitor service health

---

## CLI Quick Reference

```bash
# Projects
vikunja-api-client.py list-projects
vikunja-api-client.py get-project <id>
vikunja-api-client.py create-project "Project Name"

# Tasks
vikunja-api-client.py list-tasks
vikunja-api-client.py list-tasks <project-id>
vikunja-api-client.py create-task <project-id> "Task title"
vikunja-api-client.py complete-task <task-id>
vikunja-api-client.py get-task <task-id>

# Labels
vikunja-api-client.py list-labels

# Search
vikunja-api-client.py search "query"

# User
vikunja-api-client.py user-info

# Test
vikunja-api-client.py test-connection
```

---

## Security Considerations

1. **API Token Storage**
   - Stored in `.env` (gitignored)
   - Never commit to version control
   - Rotate periodically

2. **Access Control**
   - Token has user-specific permissions
   - Review Vikunja user roles
   - Use least privilege principle

3. **Network Security**
   - API accessed via HTTPS
   - Consider IP whitelisting if needed
   - Monitor API usage

4. **Data Privacy**
   - Tasks may contain sensitive information
   - Use appropriate project visibility settings
   - Review sharing permissions

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
- Check endpoint path
- Ensure project/task ID exists

**403 Forbidden:**
- Check user permissions
- Verify project access rights
- Review sharing settings

---

## Next Steps

- [ ] Create homelab infrastructure project
- [ ] Set up task templates for common operations
- [ ] Integrate with n8n for automated task creation
- [ ] Create labels for categorization (infrastructure, maintenance, deployment, etc.)
- [ ] Set up recurring tasks for regular maintenance
- [ ] Document task workflows and best practices

---

## References

- **Vikunja API Documentation:** https://vikunja.io/docs/api-documentation/
- **Vikunja Features:** https://vikunja.io/features/
- **API Token Format:** `tk_` prefix + 40 character hex string

---

## Related Documentation

- `@/Users/cory/Projects/homelab-nexus/documentation/N8N-API-INTEGRATION.md` - n8n automation integration
- `@/Users/cory/Projects/homelab-nexus/scripts/vikunja-api-client.py` - Python client implementation
