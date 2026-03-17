# SendGrid Setup for cloudigan.com - Final Instructions

**Date:** 2026-03-17  
**Domain:** cloudigan.com (registered with Wix, DNS managed by Wix)  
**Purpose:** Enable SendGrid email sending for Cloudigan API webhook

---

## Current Status

✅ **Completed:**
- Blue-green infrastructure deployed (CT181 LIVE, CT182 STANDBY)
- HAProxy configured for zero-downtime switching
- Wix checkout pages working with dynamic download links
- SendGrid account configured for cloudigan.com

⏳ **Remaining:**
- Add DNS records to cloudigan.com in Wix
- Verify domain in SendGrid
- Get SendGrid API key
- Deploy to STANDBY container
- Test and switch traffic

---

## DNS Records to Add in Wix Dashboard

**Domain:** cloudigan.com  
**Location:** Wix Dashboard → Domains → cloudigan.com → Manage DNS Records

### 5 CNAME Records to Add:

1. **Host:** `url3953` → **Points to:** `sendgrid.net` → **TTL:** 3600
2. **Host:** `61130637` → **Points to:** `sendgrid.net` → **TTL:** 3600
3. **Host:** `em8063` → **Points to:** `u61130637.wl138.sendgrid.net` → **TTL:** 3600
4. **Host:** `s1._domainkey` → **Points to:** `s1.domainkey.u61130637.wl138.sendgrid.net` → **TTL:** 3600
5. **Host:** `s2._domainkey` → **Points to:** `s2.domainkey.u61130637.wl138.sendgrid.net` → **TTL:** 3600

### 1 TXT Record to Add/Update:

**Host:** `_dmarc`  
**Value:** `v=DMARC1; p=quarantine; rua=mailto:re+l6nzji6h0kd@dmarc.postmarkapp.com,mailto:cory@cloudigan.com; ruf=mailto:cory@cloudigan.com; fo=1; aspf=r; adkim=r`  
**TTL:** 3600

**Note:** If a DMARC record already exists, update it with the value above (adds SendGrid support via `aspf=r` and `adkim=r`)

---

## Step-by-Step Instructions

### Step 1: Add DNS Records in Wix

1. Go to https://manage.wix.com/dashboard
2. Click **Domains** in the left sidebar
3. Find **cloudigan.com** and click **Manage DNS Records**
4. For each CNAME record:
   - Click **+ Add Record**
   - Select **CNAME**
   - Enter the **Host** and **Points to** values from above
   - Click **Save**
5. For the DMARC TXT record:
   - If `_dmarc` exists, click **Edit** and update the value
   - If it doesn't exist, click **+ Add Record**, select **TXT**, enter values
   - Click **Save**

### Step 2: Verify in SendGrid

1. Go to SendGrid Dashboard → Settings → Sender Authentication
2. Find cloudigan.com domain
3. Click **Verify**
4. Wait for green checkmarks on all DNS records (may take 5-10 minutes)

### Step 3: Create SendGrid API Key

1. SendGrid Dashboard → Settings → API Keys
2. Click **Create API Key**
3. Name: `cloudigan-api-production`
4. Permissions: **Full Access** (or **Mail Send** minimum)
5. Click **Create & View**
6. **Copy the API key** (starts with `SG.`) - you won't see it again!

### Step 4: Provide API Key

Share the SendGrid API key so it can be added to the STANDBY container.

---

## Deployment to STANDBY Container

Once the API key is provided, these steps will be automated:

```bash
# SSH to STANDBY container
ssh root@10.92.3.182

# Add SendGrid configuration
cd /opt/cloudigan-api
echo "SENDGRID_API_KEY=SG.your_key_here" >> .env
echo "SENDGRID_FROM_EMAIL=noreply@cloudigan.com" >> .env
echo "SENDGRID_FROM_NAME=Cloudigan IT Solutions" >> .env

# Restart service
systemctl restart cloudigan-api

# Verify service is running
systemctl status cloudigan-api
curl http://localhost:3000/health
```

---

## Testing

### Test Email Flow:

1. Do a Stripe test checkout (use test card: 4242 4242 4242 4242)
2. Verify email is sent to customer
3. Check email headers to confirm it's from cloudigan.com
4. Verify download links work in email

### Test Commands:

```bash
# Check STANDBY health
curl http://10.92.3.182:3000/health

# Check STANDBY via HAProxy
curl -H "Host: green.api.cloudigan.net" http://10.92.3.33/health

# View STANDBY logs
ssh root@10.92.3.182 'journalctl -u cloudigan-api -f'
```

---

## Traffic Switch

Once testing is successful:

```bash
# SSH to HAProxy
ssh root@10.92.3.33

# Edit HAProxy config
vi /etc/haproxy/haproxy.cfg

# Change this line:
#   use_backend cloudigan_api_blue if is_cloudigan_api
# To:
#   use_backend cloudigan_api_green if is_cloudigan_api

# Test config
haproxy -c -f /etc/haproxy/haproxy.cfg

# Reload HAProxy (zero downtime)
systemctl reload haproxy

# Verify traffic is going to green
curl https://api.cloudigan.net/health
```

---

## Rollback Plan

If issues occur after switching:

```bash
# SSH to HAProxy
ssh root@10.92.3.33

# Edit config back to blue
vi /etc/haproxy/haproxy.cfg
# Change: use_backend cloudigan_api_green if is_cloudigan_api
# Back to: use_backend cloudigan_api_blue if is_cloudigan_api

# Reload
systemctl reload haproxy
```

---

## Success Criteria

✅ All DNS records verified in SendGrid  
✅ SendGrid API key created and configured  
✅ STANDBY container running with SendGrid integration  
✅ Test email sent successfully from noreply@cloudigan.com  
✅ Email contains working download links  
✅ HAProxy switched to STANDBY (green)  
✅ Production traffic flowing through STANDBY  

---

**Current Blocker:** DNS records need to be added in Wix dashboard (Wix MCP tools don't support account-level DNS management)

**Next Action:** Add the 5 CNAME + 1 TXT records in Wix dashboard, then verify in SendGrid
