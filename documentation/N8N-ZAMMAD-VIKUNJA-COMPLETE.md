# n8n Workflow: Zammad → Vikunja - DEPLOYED

**Status:** ✅ Fully Operational  
**Deployed:** 2026-04-20  
**Workflow ID:** 6mcHbtq1wHF8dzBe

---

## 📊 Overview

Automated workflow that creates tasks in Vikunja when new support tickets are created in Zammad.

**Flow:**
```
New Ticket → Zammad Trigger → Webhook → n8n → Vikunja Task
```

---

## ✅ Deployment Summary

### **n8n Workflow**
- **Name:** Zammad → Vikunja Task Creation
- **ID:** `6mcHbtq1wHF8dzBe`
- **Status:** Active
- **Webhook URL:** `https://flows.cloudigan.net/webhook/zammad-ticket`

### **Vikunja Integration**
- **API Token:** Configured (ID: BRJWKbv7F1KUu5y3)
- **Target Project:** Inbox (ID: 1)
- **User:** cory@cloudigan.com

### **Zammad Configuration**
- **Webhook ID:** 1
- **Webhook Name:** n8n Vikunja Task Creation
- **Trigger ID:** 5
- **Trigger Name:** Create Vikunja Task on New Ticket
- **Condition:** ticket.action = create
- **Status:** Active

---

## 🎯 How It Works

1. **New Ticket Created in Zammad**
   - User creates ticket via email, web, or API
   - Ticket assigned number and ID

2. **Zammad Trigger Fires**
   - Trigger detects new ticket creation
   - Calls webhook with ticket data

3. **n8n Receives Webhook**
   - Webhook receives ticket payload
   - Extracts ticket details

4. **Vikunja Task Created**
   - n8n calls Vikunja API
   - Creates task in Inbox project
   - Includes ticket link and details

5. **Confirmation Returned**
   - n8n returns success response
   - Includes task ID

---

## 📋 Task Details

Tasks created in Vikunja include:

**Title:** `Ticket #[NUMBER]: [TICKET TITLE]`

**Description:**
```
**Zammad Ticket:** https://support.cloudigan.net/#ticket/zoom/[ID]

**Customer:** [Customer ID]
**Priority:** [Priority ID]
**State:** [State ID]

**Description:**
[Original ticket body]

---
*Auto-created from Zammad ticket #[NUMBER]*
```

**Metadata:**
- **Priority:** Medium (2)
- **Project:** Inbox (1)
- **Auto-created:** Yes

---

## 🧪 Test Results

**Test Ticket #29011:**
- **Title:** Test Zammad → Vikunja Integration
- **Zammad ID:** 11
- **Vikunja Task ID:** 43
- **Created:** 2026-04-20 07:16:37
- **Status:** ✅ Successfully created

---

## 🔧 Technical Details

### Zammad Webhook Payload

Zammad sends:
```json
{
  "ticket": {
    "id": 11,
    "number": "29011",
    "title": "Ticket Title",
    "customer_id": "...",
    "priority_id": 2,
    "state_id": 2,
    "group": "Users"
  },
  "article": {
    "subject": "...",
    "body": "...",
    "type": "note"
  }
}
```

### n8n Workflow Nodes

1. **Webhook** - Receives POST requests from Zammad
2. **Create Vikunja Task** - HTTP PUT to Vikunja API
3. **Webhook Response** - Returns success confirmation

### Zammad Trigger Configuration

```json
{
  "name": "Create Vikunja Task on New Ticket",
  "condition": {
    "ticket.action": {
      "operator": "is",
      "value": "create"
    }
  },
  "perform": {
    "notification.webhook": {
      "webhook_id": "1"
    }
  },
  "active": true
}
```

---

## 📊 Monitoring & Maintenance

### Check Workflow Status

```bash
export N8N_TOKEN="<token>"
curl -H "X-N8N-API-KEY: $N8N_TOKEN" \
  https://flows.cloudigan.net/api/v1/workflows/6mcHbtq1wHF8dzBe | jq '{id, name, active}'
```

### View Recent Executions

```bash
curl -H "X-N8N-API-KEY: $N8N_TOKEN" \
  "https://flows.cloudigan.net/api/v1/executions?workflowId=6mcHbtq1wHF8dzBe&limit=10"
```

### Check Zammad Webhook

```bash
curl -H "Authorization: Token token=<token>" \
  https://support.cloudigan.net/api/v1/webhooks/1 | jq '{id, name, active}'
```

### Check Zammad Trigger

```bash
curl -H "Authorization: Token token=<token>" \
  https://support.cloudigan.net/api/v1/triggers/5 | jq '{id, name, active}'
```

### View Recent Vikunja Tasks

```bash
curl -H "Authorization: Bearer <token>" \
  https://tasks.cloudigan.net/api/v1/projects/1/tasks | jq '[.[] | {id, title, created}] | sort_by(.created) | reverse | .[0:5]'
```

---

## 🔍 Troubleshooting

### No Tasks Being Created?

1. **Check n8n workflow is active:**
   ```bash
   curl -H "X-N8N-API-KEY: $N8N_TOKEN" \
     https://flows.cloudigan.net/api/v1/workflows/6mcHbtq1wHF8dzBe | jq '.active'
   ```

2. **Check Zammad trigger is active:**
   ```bash
   curl -H "Authorization: Token token=<token>" \
     https://support.cloudigan.net/api/v1/triggers/5 | jq '.active'
   ```

3. **Check Zammad webhook is active:**
   ```bash
   curl -H "Authorization: Token token=<token>" \
     https://support.cloudigan.net/api/v1/webhooks/1 | jq '.active'
   ```

4. **Test webhook manually:**
   ```bash
   curl -X POST https://flows.cloudigan.net/webhook/zammad-ticket \
     -H "Content-Type: application/json" \
     -d '{"ticket":{"id":999,"number":"99999","title":"Test"},"article":{"body":"Test body"}}'
   ```

### Tasks Created in Wrong Project?

- Default project is Inbox (ID: 1)
- To change, update workflow node parameter `project_id`

### Task Description Not Formatted?

- Check n8n workflow execution logs
- Verify Zammad webhook payload structure
- Review Vikunja API response

---

## 🔐 Security

- **Webhook URL:** Public but requires specific JSON structure
- **Vikunja API Token:** Stored encrypted in n8n credentials
- **Zammad API Token:** Used for webhook configuration only
- **No Authentication:** Webhook has no auth (consider adding in future)

---

## 📈 Future Enhancements

### Phase 2 (Planned)
- [ ] Update task when ticket is updated
- [ ] Close task when ticket is closed
- [ ] Add ticket priority mapping to task priority
- [ ] Assign task based on ticket assignee
- [ ] Add labels/tags from ticket categories

### Phase 3 (Future)
- [ ] Two-way sync (update ticket from task)
- [ ] Time tracking integration
- [ ] Automatic task due dates based on SLA
- [ ] Create subtasks for ticket articles
- [ ] Integration with Kimai for time tracking

---

## 📚 Related Documentation

- [n8n API Integration](./N8N-API-INTEGRATION.md)
- [Vikunja Setup](./VIKUNJA-SETUP.md)
- [Zammad Configuration](./ZAMMAD-SETUP.md)
- [n8n Uptime Kuma → Zammad Workflow](./N8N-UPTIME-KUMA-ZAMMAD-COMPLETE.md)

---

## 📝 Change Log

**2026-04-20:**
- ✅ Created n8n workflow (ID: 6mcHbtq1wHF8dzBe)
- ✅ Configured Vikunja API credentials
- ✅ Created Zammad webhook (ID: 1)
- ✅ Created Zammad trigger (ID: 5)
- ✅ Tested and verified task creation
- ✅ Deployed to production

---

## ✅ Deployment Checklist

- [x] n8n workflow created
- [x] Vikunja API token configured
- [x] Workflow activated
- [x] Zammad webhook created
- [x] Zammad trigger created and activated
- [x] Test ticket created successfully
- [x] Test task verified in Vikunja
- [x] Documentation completed
- [x] Production deployment verified

---

**Status:** ✅ Fully Operational  
**Maintained by:** Infrastructure Team  
**Last Updated:** 2026-04-20 11:16 UTC
