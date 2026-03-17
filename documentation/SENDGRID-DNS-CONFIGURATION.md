# SendGrid DNS Configuration for cloudigan.com

**Date:** 2026-03-17  
**Purpose:** Configure SendGrid email authentication for cloudigan.com domain  
**Status:** Ready to implement

---

## DNS Records to Add

### **5 CNAME Records (Add these):**

1. **CNAME Record 1:**
   - Host: `url3953.cloudigan.com`
   - Points to: `sendgrid.net`
   - TTL: 3600

2. **CNAME Record 2:**
   - Host: `61130637.cloudigan.com`
   - Points to: `sendgrid.net`
   - TTL: 3600

3. **CNAME Record 3:**
   - Host: `em8063.cloudigan.com`
   - Points to: `u61130637.wl138.sendgrid.net`
   - TTL: 3600

4. **CNAME Record 4 (DKIM Key 1):**
   - Host: `s1._domainkey.cloudigan.com`
   - Points to: `s1.domainkey.u61130637.wl138.sendgrid.net`
   - TTL: 3600

5. **CNAME Record 5 (DKIM Key 2):**
   - Host: `s2._domainkey.cloudigan.com`
   - Points to: `s2.domainkey.u61130637.wl138.sendgrid.net`
   - TTL: 3600

### **1 TXT Record (Update existing DMARC):**

**Current DMARC Record:**
```
v=DMARC1; p=quarantine; rua=mailto:re+l6nzji6h0kd@dmarc.postmarkapp.com; ruf=mailto:cory@cloudigan.com; fo=1
```

**Updated DMARC Record (to support both M365 and SendGrid):**
```
v=DMARC1; p=quarantine; rua=mailto:re+l6nzji6h0kd@dmarc.postmarkapp.com,mailto:cory@cloudigan.com; ruf=mailto:cory@cloudigan.com; fo=1; aspf=r; adkim=r
```

**Changes made:**
- Added `aspf=r` - Relaxed SPF alignment (allows SendGrid subdomains)
- Added `adkim=r` - Relaxed DKIM alignment (allows SendGrid DKIM)
- Combined reporting emails with comma separator

---

## How to Add in Wix

1. Go to **Wix Dashboard** → **cloudigan.com site**
2. **Settings** → **Domains** → **cloudigan.com**
3. Click **Manage DNS Records**
4. **Add the 5 CNAME records** (click "+ Add Record" for each)
5. **Update the existing DMARC TXT record** with the new value
6. Click **Save**

---

## Verification

After adding the records:

1. Wait 5-10 minutes for DNS propagation
2. In SendGrid, click **Verify** on the domain authentication page
3. SendGrid will check all DNS records
4. Once verified, you'll get a green checkmark

---

## Next Steps

Once DNS is verified in SendGrid:

1. **Get SendGrid API Key:**
   - SendGrid Dashboard → Settings → API Keys
   - Create API Key → Name: `cloudigan-api-production`
   - Permissions: Full Access (or Mail Send)
   - Copy the key (starts with `SG.`)

2. **Add to STANDBY Container:**
   ```bash
   ssh root@10.92.3.182
   cd /opt/cloudigan-api
   echo "SENDGRID_API_KEY=SG.your_key_here" >> .env
   echo "SENDGRID_FROM_EMAIL=noreply@cloudigan.com" >> .env
   systemctl restart cloudigan-api
   ```

3. **Test Email Flow:**
   - Do a Stripe test checkout
   - Verify email is sent to customer
   - Check email headers show cloudigan.com domain

4. **Switch Traffic:**
   - Update HAProxy to route to green (STANDBY)
   - Monitor for issues
   - Green becomes new LIVE

---

## Troubleshooting

### DNS Not Verifying
- Check DNS propagation: `dig CNAME em8063.cloudigan.com +short`
- Wait up to 48 hours for full propagation
- Verify records match exactly (no typos)

### Email Not Sending
- Check SendGrid API key is correct
- Verify service restarted: `systemctl status cloudigan-api`
- Check logs: `journalctl -u cloudigan-api -f | grep -i sendgrid`

---

**Status:** Waiting for DNS records to be added in Wix
