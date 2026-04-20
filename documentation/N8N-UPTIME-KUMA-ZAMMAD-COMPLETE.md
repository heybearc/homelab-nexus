# n8n Workflow: Uptime Kuma → Zammad - DEPLOYED

**Status:** ✅ Fully Operational  
**Deployed:** 2026-04-20  
**Workflow ID:** hpcPBbttShe5Uc7j

---

## 📊 Overview

Automated workflow that creates high-priority support tickets in Zammad when Uptime Kuma detects service outages.

**Flow:**
```
Service Down → Uptime Kuma → Webhook → n8n → Zammad Ticket
```

---

## ✅ Deployment Summary

### **n8n Workflow**
- **Name:** Uptime Kuma → Zammad Ticket Creation
- **ID:** `hpcPBbttShe5Uc7j`
- **Status:** Active
- **Webhook URL:** `https://flows.cloudigan.net/webhook/uptime-kuma-alert`

### **Zammad Integration**
- **API Token:** Configured (ID: g9DGyY5zBJy8ruQn)
- **User:** cory@cloudigan.com
- **Permissions:** ticket.agent

### **Uptime Kuma Configuration**
- **Notification Name:** n8n Zammad Tickets
- **Type:** Webhook
- **Status:** Active and set as default
- **Monitors Configured:** 28 active monitors
- **Webhook URL:** https://flows.cloudigan.net/webhook/uptime-kuma-alert

---

## 🎯 Configured Monitors

All 28 active monitors are now configured to send alerts:

**Production Services:**
- QuantShift Dashboard (Public)
- TheoShift Production (Public)
- LDC Tools Production (Public)

**Internal Infrastructure:**
- Grafana (Internal)
- Prometheus (Internal)
- PostgreSQL Cluster
- Redis
- HAProxy
- And 20 more...

---

## 📋 Ticket Details

When a service goes down, Zammad tickets are created with:

**Title:** `[Service Name] is DOWN`

**Body:**
```
Service: [Service Name]
Status: DOWN
URL: [Service URL]
Time: [Timestamp]
Message: [Error Message]

Automatic alert from Uptime Kuma monitoring system.
```

**Metadata:**
- **Priority:** High (3)
- **State:** Open (2)
- **Group:** Users
- **Customer:** cory@cloudigan.com

---

## 🧪 Test Results

**Test Ticket #10:**
- **Title:** Production API Server is DOWN
- **Created:** 2026-04-20 10:35:26 UTC
- **Status:** ✅ Successfully created
- **Body:** Complete service details included

---

## 🔧 Technical Details

### Webhook Payload Structure

Uptime Kuma sends:
```json
{
  "monitor": {
    "name": "Service Name",
    "url": "https://service.example.com"
  },
  "heartbeat": {
    "status": 0,
    "time": "2026-04-20 10:00:00",
    "msg": "Error message"
  }
}
```

### n8n Workflow Nodes

1. **Webhook** - Receives POST requests from Uptime Kuma
2. **Create Zammad Ticket** - HTTP Request to Zammad API
3. **Webhook Response** - Returns success confirmation

### Database Configuration

**Uptime Kuma Database:** `/opt/uptime-kuma-data/kuma.db`

**Notification Record:**
```sql
INSERT INTO notification (name, active, user_id, is_default, config)
VALUES ('n8n Zammad Tickets', 1, 1, 1, '...')
```

**Monitor Links:**
```sql
INSERT INTO monitor_notification (monitor_id, notification_id)
SELECT id, 1 FROM monitor WHERE active = 1
```

---

## 🚀 How It Works

1. **Service Goes Down**
   - Uptime Kuma detects service failure
   - Status changes to 0 (down)

2. **Webhook Triggered**
   - Uptime Kuma sends POST to n8n webhook
   - Includes monitor name, URL, time, error message

3. **n8n Processes Request**
   - Receives webhook payload
   - Extracts service details
   - Formats ticket body

4. **Zammad Ticket Created**
   - n8n calls Zammad API
   - Creates high-priority ticket
   - Assigns to Users group
   - Sets customer to cory@cloudigan.com

5. **Confirmation Returned**
   - n8n returns success response
   - Includes ticket ID

---

## 📊 Monitoring & Maintenance

### Check Workflow Status

```bash
export N8N_TOKEN="<token>"
curl -H "X-N8N-API-KEY: $N8N_TOKEN" \
  https://flows.cloudigan.net/api/v1/workflows/hpcPBbttShe5Uc7j | jq '{id, name, active}'
```

### View Recent Executions

```bash
curl -H "X-N8N-API-KEY: $N8N_TOKEN" \
  "https://flows.cloudigan.net/api/v1/executions?workflowId=hpcPBbttShe5Uc7j&limit=10"
```

### Check Uptime Kuma Notification

```bash
ssh root@10.92.3.82 "sqlite3 /opt/uptime-kuma-data/kuma.db \
  'SELECT id, name, active, is_default FROM notification;'"
```

### Verify Monitor Links

```bash
ssh root@10.92.3.82 "sqlite3 /opt/uptime-kuma-data/kuma.db \
  'SELECT COUNT(*) FROM monitor_notification;'"
```

---

## 🔍 Troubleshooting

### No Tickets Being Created?

1. **Check n8n workflow is active:**
   ```bash
   curl -H "X-N8N-API-KEY: $N8N_TOKEN" \
     https://flows.cloudigan.net/api/v1/workflows/hpcPBbttShe5Uc7j | jq '.active'
   ```

2. **Check Uptime Kuma notification:**
   ```bash
   ssh root@10.92.3.82 "sqlite3 /opt/uptime-kuma-data/kuma.db \
     'SELECT active FROM notification WHERE id = 1;'"
   ```

3. **Test webhook manually:**
   ```bash
   curl -X POST https://flows.cloudigan.net/webhook/uptime-kuma-alert \
     -H "Content-Type: application/json" \
     -d '{"monitor":{"name":"Test"},"heartbeat":{"status":0,"time":"now","msg":"test"}}'
   ```

### Tickets Not Formatted Correctly?

- Check n8n workflow execution logs
- Verify Zammad API response
- Review webhook payload structure

### Monitor Not Sending Alerts?

1. **Check monitor is linked:**
   ```bash
   ssh root@10.92.3.82 "sqlite3 /opt/uptime-kuma-data/kuma.db \
     'SELECT * FROM monitor_notification WHERE monitor_id = <ID>;'"
   ```

2. **Re-link monitor:**
   ```bash
   ssh root@10.92.3.82 "sqlite3 /opt/uptime-kuma-data/kuma.db \
     'INSERT INTO monitor_notification (monitor_id, notification_id) VALUES (<ID>, 1);'"
   ```

---

## 🔐 Security

- **Webhook URL:** Public but requires specific JSON structure
- **Zammad API Token:** Stored encrypted in n8n credentials
- **Token Permissions:** Limited to ticket.agent only
- **No Authentication:** Webhook has no auth (consider adding in future)

---

## 📈 Future Enhancements

### Phase 2 (Planned)
- [ ] Auto-close tickets when service recovers
- [ ] Add severity levels (critical, warning, info)
- [ ] Include uptime percentage in ticket
- [ ] Send Teams/Slack notifications
- [ ] Create Vikunja tasks for infrastructure team

### Phase 3 (Future)
- [ ] Escalation rules (if down > 15 min)
- [ ] On-call rotation integration
- [ ] SLA tracking
- [ ] Incident timeline in BookStack
- [ ] Auto-remediation workflows

---

## 📚 Related Documentation

- [n8n API Integration](./N8N-API-INTEGRATION.md)
- [Uptime Kuma Setup](./UPTIME-KUMA-SETUP.md)
- [Zammad Configuration](./ZAMMAD-SETUP.md)
- [MSP Platform Overview](./MSP-PLATFORM-ANALYSIS.md)

---

## 📝 Change Log

**2026-04-20:**
- ✅ Created n8n workflow (ID: hpcPBbttShe5Uc7j)
- ✅ Configured Zammad API credentials
- ✅ Created Uptime Kuma webhook notification
- ✅ Linked all 28 active monitors
- ✅ Tested and verified ticket creation
- ✅ Deployed to production

---

## ✅ Deployment Checklist

- [x] n8n workflow created
- [x] Zammad API token configured
- [x] Workflow activated
- [x] Uptime Kuma notification created
- [x] All monitors linked to notification
- [x] Test ticket created successfully
- [x] Documentation completed
- [x] Production deployment verified

---

**Status:** ✅ Fully Operational  
**Maintained by:** Infrastructure Team  
**Last Updated:** 2026-04-20 10:55 UTC
