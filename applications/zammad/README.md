# Zammad Support Ticket System

**Container:** CT186 @ 10.92.3.77  
**Domain:** https://support.cloudigan.net  
**Database:** External PostgreSQL (CT131: zammad_tickets)  
**Email:** support@cloudigan.com (Microsoft Graph API)

---

## Authentication

### Team Members (Agents/Admins)
- **Method:** Microsoft 365 OIDC SSO
- **Login:** https://support.cloudigan.net → "Sign in with Microsoft"
- **Auto-provisioning:** First login creates user account
- **Role Assignment:** Managed via Zammad admin panel or API

### Customers
- **Method:** Email-based (no login required)
- **Access:** Email support@cloudigan.com to create tickets
- **Portal:** Optional customer portal with separate authentication

---

## API Access

**Personal Access Token:**
```
doghcRUPpmvQ5QnzTm011XtdW7qI4jRJUWyjN8oPlLAs_OtVAt2_IKxLNC8hQbhZ
```

**API Endpoint:** `https://support.cloudigan.net/api/v1/`

**Usage Example:**
```bash
curl -H "Authorization: Token doghcRUPpmvQ5QnzTm011XtdW7qI4jRJUWyjN8oPlLAs_OtVAt2_IKxLNC8hQbhZ" \
  https://support.cloudigan.net/api/v1/users/me
```

**Token Management:**
- Created in: Zammad UI → Profile → Token Access
- Scope: Full API access
- Rotation: Consider rotating periodically
- Revocation: Via Zammad UI

---

## Email Configuration

### Inbound Email (Microsoft Graph API)
- **Mailbox:** support@cloudigan.com (shared mailbox)
- **Method:** Microsoft Graph API
- **Folder:** Inbox
- **Frequency:** Checks every 30 seconds
- **Behavior:** Creates ticket automatically from emails

### Outbound Email (Microsoft Graph API)
- **From:** Cloudigan Support <support@cloudigan.com>
- **Method:** Microsoft Graph API
- **Signatures:** Configured (see below)

### Email Notification (SMTP)
- **Purpose:** Internal agent notifications
- **Status:** Uses local sendmail (may go to spam)
- **Future:** Configure with M365 SMTP for proper delivery

---

## Signatures

### Signature ID 2: "Cloudigan Support" (with logo)
- **Status:** Active
- **Contains:** Embedded Cloudigan logo (base64) + contact info
- **Size:** ~15KB
- **Assigned to:** Users group (ID: 1)

### Signature ID 3: "Cloudigan Simple" (text-only)
- **Status:** Active
- **Contains:** Plain text signature without logo
- **Use case:** Fallback for email clients that don't support images

---

## Triggers

### Trigger ID 1: Auto-Reply (on new tickets)
- **Purpose:** Send confirmation to customers when ticket is created
- **Recipient:** Customer (article_last_sender)
- **Subject:** `Ticket Received [Ticket##{ticket.number}]`
- **Body:** Personalized greeting with ticket number + embedded logo signature
- **Status:** ✅ Active with Cloudigan logo signature

### Trigger ID 4: Admin Notification
- **Purpose:** Notify admin of new tickets
- **Recipient:** cory@cloudigan.com
- **Subject:** `New Support Ticket: #{ticket.title}`
- **Content:** Ticket details and link to view in Zammad
- **Status:** Active

---

## Scripts

Located in `applications/zammad/scripts/`:

1. **update-zammad-trigger.sh** - Updates auto-reply trigger
2. **create-admin-notification-trigger.sh** - Creates admin notification
3. **create-simple-signature.sh** - Creates text-only signature
4. **update-autoreply-with-signature.sh** - Embeds text-only signature in auto-reply
5. **update-autoreply-with-logo.sh** - Embeds logo signature in auto-reply (ACTIVE)

---

## Outstanding Issues

### ~~Issue 1: Auto-Reply Signature Not Displaying~~ ✅ RESOLVED
**Problem:** `#{signature}` placeholder doesn't work in triggers  
**Solution:** Embedded signature HTML with logo directly into trigger body  
**Status:** Fixed - Logo signature now displays in auto-reply emails  
**Date Resolved:** April 7, 2026

### Issue 2: Admin Notifications Not Received
**Problem:** Admin notification emails not arriving  
**Possible Causes:** Graph API config, spam filtering, trigger timing  
**Status:** Needs testing  
**Priority:** Low (can check Zammad dashboard directly)

---

## Customer Organizations

**Current:** Not configured (each customer is independent)

**When to configure:**
- Multi-user client companies
- Shared ticket visibility needed
- SLA requirements per client
- Reporting by organization

**Setup:** Admin → Manage → Organizations

---

## Maintenance

### Backup
- **Database:** Included in CT131 PostgreSQL backups
- **Container:** Included in Proxmox backup schedule
- **Frequency:** Daily

### Updates
- **Method:** Docker Compose (`docker-compose pull && docker-compose up -d`)
- **Frequency:** Monthly or as needed for security patches
- **Testing:** Test in staging before production

### Monitoring
- **Container:** Monitored via Prometheus/Grafana
- **Email:** Monitor Graph API connection status
- **Database:** Monitor PostgreSQL connection pool

---

## References

- **Zammad API Docs:** https://docs.zammad.org/en/latest/api/intro.html
- **Deployment Docs:** `documentation/MSP-PLATFORM-PHASE1-DEPLOYMENT.md`
- **Database:** CT131 (10.92.3.21) - `zammad_tickets` database
- **Container Config:** `/opt/zammad/.env` on CT186
