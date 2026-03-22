# Semaphore Microsoft Teams Alerts - Configuration

**Date:** March 21, 2026  
**Status:** ✅ Configured and Active

---

## Overview

Semaphore is now configured to send alerts to Microsoft Teams when Ansible playbooks are executed. You'll receive notifications for:
- Playbook execution start
- Playbook success
- Playbook failures
- Task errors

---

## Configuration Details

### Teams Webhook
- **Channel:** Cloudigan Teams Channel
- **Webhook URL:** Configured in Semaphore
- **Alert Type:** Microsoft Teams Incoming Webhook

### Semaphore Settings
```json
"microsoft_teams_alert": true,
"microsoft_teams_url": "https://cloudigan.webhook.office.com/webhookb2/..."
```

---

## What You'll See in Teams

When a playbook runs, you'll receive a Teams notification with:
- **Playbook name**
- **Execution status** (Running/Success/Failed)
- **User who triggered it**
- **Timestamp**
- **Link to view details** in Semaphore

---

## Testing the Integration

A test message was sent to verify the webhook is working. You should have received:
> 🎉 Semaphore Ansible alerts are now configured! You will receive notifications here when playbooks run.

---

## Managing Alerts

### Enable/Disable Alerts
Alerts can be managed in two ways:

1. **Per Project in Semaphore UI:**
   - Go to Project Settings
   - Toggle "Microsoft Teams Alerts"

2. **Globally via Config:**
   - Edit `/tmp/semaphore/config.json` on CT183
   - Set `"microsoft_teams_alert": false` to disable
   - Restart Semaphore service

### Change Webhook URL
If you need to change the Teams channel or webhook:
1. Create new webhook in Teams
2. Update `/tmp/semaphore/config.json`
3. Restart Semaphore: `systemctl restart semaphore`

---

## Alert Examples

### Successful Playbook
```
✅ Playbook Completed Successfully
Name: Update System Packages
User: admin
Duration: 2m 34s
View Details: https://ansible.cloudigan.net/project/1/history
```

### Failed Playbook
```
❌ Playbook Failed
Name: Deploy Application
User: admin
Error: Connection timeout to host 10.92.3.50
View Details: https://ansible.cloudigan.net/project/1/history
```

---

## Next Steps: Microsoft 365 SSO

To enable SSO with Microsoft 365 (Entra ID), you'll need to:

1. **Register App in Entra ID:**
   - Go to Azure Portal → Entra ID → App Registrations
   - Create new registration for "Semaphore"
   - Set redirect URI: `https://ansible.cloudigan.net/auth/oidc/callback`

2. **Configure OIDC in Semaphore:**
   - Add OIDC provider configuration
   - Set client ID and secret from Entra ID
   - Configure user attribute mappings

3. **Benefits:**
   - Single sign-on with M365 accounts
   - No separate passwords
   - Centralized user management
   - Aligns with hybrid SSO architecture

Would you like to set up M365 SSO next?

---

## Troubleshooting

### Alerts Not Appearing
1. Check Semaphore is running: `systemctl status semaphore`
2. Verify webhook URL is correct in config
3. Test webhook manually with curl
4. Check Teams channel permissions

### Service Issues
```bash
# View logs
journalctl -u semaphore -f

# Restart service
systemctl restart semaphore

# Check config
cat /tmp/semaphore/config.json | grep teams
```

---

## File Locations

- **Config:** `/tmp/semaphore/config.json` (on CT183)
- **Service:** `/etc/systemd/system/semaphore.service` (on CT183)
- **Documentation:** `~/Projects/homelab-nexus/documentation/`
