# n8n Workflow: Uptime Kuma → Zammad Ticket Creation

**Created:** 2026-04-20  
**Purpose:** Automatically create Zammad support tickets when Uptime Kuma detects service outages

---

## 📋 Overview

This workflow automatically creates high-priority tickets in Zammad when Uptime Kuma detects a service is down.

**Flow:**
1. Uptime Kuma detects service down
2. Sends webhook to n8n
3. n8n filters for "down" status only
4. Creates ticket in Zammad with service details
5. Returns confirmation to Uptime Kuma

---

## 🔧 Setup Instructions

### Step 1: Get Zammad API Token

1. Log into Zammad: https://support.cloudigan.net
2. Click your profile (top right) → **Profile** → **Token Access**
3. Click **"Create"** to generate a new API token
4. Name it: `n8n Automation`
5. Permissions needed:
   - `ticket.agent` (to create tickets)
   - `ticket.customer` (to view customer info)
6. **Copy the token** - you'll need it in Step 3

---

### Step 2: Configure n8n Zammad Credentials

1. Open n8n: https://flows.cloudigan.net
2. Go to **Settings** → **Credentials** → **New Credential**
3. Search for and select **"Zammad API"**
4. Fill in:
   - **Name:** `Zammad Production`
   - **Base URL:** `https://support.cloudigan.net`
   - **Access Token:** (paste token from Step 1)
5. Click **"Test"** to verify connection
6. Click **"Save"**

---

### Step 3: Import the Workflow

1. In n8n, click **"Workflows"** → **"Add Workflow"**
2. Click the **"⋮"** menu (top right) → **"Import from File"**
3. Upload the workflow file: `/tmp/uptime-kuma-to-zammad-workflow.json`
4. The workflow will open in the editor

---

### Step 4: Configure the Workflow

1. Click on the **"Create Zammad Ticket"** node
2. In the **Credentials** dropdown, select `Zammad Production`
3. Verify these settings:
   - **Group:** `Users` (or your preferred group)
   - **Customer:** `admin@cloudigan.com` (or your admin email)
   - **Priority:** `2 high`
   - **Tags:** `monitoring`, `uptime-kuma`, `automated`
4. Click **"Save"** (top right)

---

### Step 5: Activate the Workflow

1. Click the **toggle switch** at the top to activate
2. The workflow is now **ACTIVE** and listening for webhooks

---

### Step 6: Get the Webhook URL

1. Click on the **"Webhook - Uptime Kuma Alert"** node
2. Copy the **Production URL** (looks like: `https://flows.cloudigan.net/webhook/uptime-kuma-alert`)
3. Keep this URL - you'll need it for Uptime Kuma

---

### Step 7: Configure Uptime Kuma Notifications

1. Log into Uptime Kuma: https://uptime.cloudigan.net
   - Username: `admin`
   - Password: `Cloudigan2026!`

2. Go to **Settings** → **Notifications**

3. Click **"Setup Notification"**

4. Configure:
   - **Notification Type:** `Webhook`
   - **Friendly Name:** `n8n Zammad Ticket Creation`
   - **POST URL:** (paste webhook URL from Step 6)
   - **Content Type:** `application/json`
   - **Custom Body (optional):**
     ```json
     {
       "monitor": {
         "name": "[monitorName]",
         "url": "[monitorURL]"
       },
       "heartbeat": {
         "status": "[status]",
         "time": "[time]",
         "msg": "[msg]"
       }
     }
     ```

5. Click **"Test"** to send a test notification

6. Click **"Save"**

---

### Step 8: Apply to Monitors

1. In Uptime Kuma, go to each monitor you want to enable
2. Click **"Edit"**
3. Scroll to **"Notifications"**
4. Select **"n8n Zammad Ticket Creation"**
5. Click **"Save"**

**Recommended monitors to enable:**
- ✅ Production applications (TheoShift, QuantShift, LDC Tools)
- ✅ Critical infrastructure (PostgreSQL, Redis, HAProxy)
- ✅ Customer-facing services (Zammad, BookStack)

---

## 🧪 Testing the Workflow

### Test 1: Manual Webhook Test

```bash
# Send a test "down" alert
curl -X POST https://flows.cloudigan.net/webhook/uptime-kuma-alert \
  -H "Content-Type: application/json" \
  -d '{
    "monitor": {
      "name": "Test Service",
      "url": "https://test.example.com"
    },
    "heartbeat": {
      "status": "0",
      "time": "2026-04-20 10:00:00",
      "msg": "Connection timeout"
    }
  }'
```

**Expected result:**
- ✅ Ticket created in Zammad
- ✅ Title: "Test Service is DOWN"
- ✅ Priority: High
- ✅ Tags: monitoring, uptime-kuma, automated

### Test 2: Uptime Kuma Test Notification

1. In Uptime Kuma Settings → Notifications
2. Click **"Test"** next to your webhook notification
3. Check Zammad for new ticket

---

## 📊 Workflow Details

### Webhook Payload Structure

Uptime Kuma sends this JSON structure:

```json
{
  "monitor": {
    "name": "Service Name",
    "url": "https://service.example.com"
  },
  "heartbeat": {
    "status": "0",  // 0 = down, 1 = up
    "time": "2026-04-20 10:00:00",
    "msg": "Error message"
  }
}
```

### Ticket Template

Created tickets include:

**Title:** `[Service Name] is DOWN`

**Body:**
```
Service: [Service Name]
Status: DOWN
URL: [Service URL]
Time: [Timestamp]

Automatic alert from Uptime Kuma monitoring system.
```

**Metadata:**
- Priority: High
- Group: Users
- Tags: monitoring, uptime-kuma, automated
- Type: Note (internal)

---

## 🔄 Workflow Enhancements (Future)

### Phase 2 Improvements:
- [ ] Auto-assign tickets based on service type
- [ ] Include historical uptime data
- [ ] Add severity levels (critical, warning, info)
- [ ] Auto-close tickets when service recovers
- [ ] Send Teams/Slack notifications
- [ ] Create Vikunja tasks for infrastructure team

### Phase 3 Improvements:
- [ ] Escalation rules (if down > 15 min, escalate)
- [ ] On-call rotation integration
- [ ] SLA tracking
- [ ] Incident timeline in BookStack

---

## 📝 Troubleshooting

### Webhook not triggering?
1. Check n8n workflow is **ACTIVE** (toggle at top)
2. Verify webhook URL in Uptime Kuma matches n8n
3. Check n8n execution history for errors

### Tickets not creating?
1. Verify Zammad API credentials in n8n
2. Check Zammad user has permission to create tickets
3. Review n8n execution logs for API errors

### Wrong ticket details?
1. Check Uptime Kuma webhook body format
2. Verify n8n node mappings ({{$json.body.monitor.name}})
3. Test with manual curl command

---

## 🔐 Security Notes

- Webhook URL is public but requires specific JSON structure
- Consider adding authentication header for production
- Zammad API token has limited permissions (ticket.agent only)
- Store API tokens in n8n credentials (encrypted)

---

## 📚 Related Documentation

- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma/wiki)
- [Zammad API Documentation](https://docs.zammad.org/en/latest/api/intro.html)
- [n8n Webhook Documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)

---

## ✅ Checklist

- [ ] Zammad API token created
- [ ] n8n Zammad credentials configured
- [ ] Workflow imported and activated
- [ ] Webhook URL copied
- [ ] Uptime Kuma notification configured
- [ ] Applied to critical monitors
- [ ] Tested with manual webhook
- [ ] Tested with Uptime Kuma test notification
- [ ] Verified ticket creation in Zammad

---

**Status:** Ready for production use  
**Maintained by:** Infrastructure Team  
**Last Updated:** 2026-04-20
