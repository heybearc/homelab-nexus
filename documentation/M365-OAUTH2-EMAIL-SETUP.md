# M365 OAuth2 Email Setup for Cloudigan API

**Date:** 2026-03-17  
**Purpose:** Configure Microsoft 365 OAuth2 authentication for sending emails from webhook  
**Method:** Azure AD App Registration + Microsoft Graph API

---

## Overview

Using OAuth2 with Microsoft Graph API is the recommended approach for M365 email sending:
- ✅ No app passwords needed
- ✅ More secure (token-based authentication)
- ✅ Centralized permission management
- ✅ Audit trail in Azure AD
- ✅ Works with shared mailboxes

---

## Step 1: Register Azure AD Application

1. **Go to Azure Portal:**
   - Navigate to: https://portal.azure.com
   - Sign in with your admin account

2. **Create App Registration:**
   - Azure Active Directory → App registrations → New registration
   - **Name:** `Cloudigan API Email Service`
   - **Supported account types:** Accounts in this organizational directory only (Single tenant)
   - **Redirect URI:** Leave blank (not needed for daemon app)
   - Click **Register**

3. **Note the IDs:**
   - **Application (client) ID:** Copy this (e.g., `12345678-1234-1234-1234-123456789abc`)
   - **Directory (tenant) ID:** Copy this (e.g., `87654321-4321-4321-4321-cba987654321`)

---

## Step 2: Create Client Secret

1. **In your app registration:**
   - Go to: **Certificates & secrets**
   - Click: **New client secret**

2. **Configure Secret:**
   - **Description:** `Cloudigan API SMTP OAuth`
   - **Expires:** 24 months (or your preference)
   - Click **Add**

3. **Copy the Secret Value:**
   - **IMPORTANT:** Copy the secret value immediately
   - You won't be able to see it again
   - Store it securely

---

## Step 3: Configure API Permissions

1. **Add Permissions:**
   - In your app registration, go to: **API permissions**
   - Click: **Add a permission**
   - Select: **Microsoft Graph**
   - Select: **Application permissions** (NOT Delegated)
   - Search for: `Mail.Send`
   - Check: **Mail.Send**
   - Click: **Add permissions**

2. **Grant Admin Consent:**
   - Click: **Grant admin consent for [Your Organization]**
   - Confirm the consent
   - Status should show green checkmark: "Granted for [Your Organization]"

---

## Step 4: Configure Environment Variables

Add these to STANDBY container `/opt/cloudigan-api/.env`:

```bash
# M365 OAuth2 Configuration
AZURE_CLIENT_ID=<your_application_client_id>
AZURE_TENANT_ID=<your_directory_tenant_id>
AZURE_CLIENT_SECRET=<your_client_secret>

# Email Configuration
EMAIL_FROM=noreply@cloudigan.com
EMAIL_FROM_NAME=Cloudigan IT Solutions
```

---

## Step 5: Update Webhook Code

Replace the existing email sending code with OAuth2 implementation:

```javascript
const M365OAuthMailer = require('./m365-oauth-mailer');

// Initialize mailer
const mailer = new M365OAuthMailer({
  clientId: process.env.AZURE_CLIENT_ID,
  tenantId: process.env.AZURE_TENANT_ID,
  clientSecret: process.env.AZURE_CLIENT_SECRET,
  fromEmail: process.env.EMAIL_FROM,
  fromName: process.env.EMAIL_FROM_NAME
});

// Send email
async function sendDownloadEmail(customerEmail, customerName, downloadLinks) {
  const emailHtml = `
    <h1>Welcome, ${customerName}!</h1>
    <p>Thank you for your purchase. Your download links are ready:</p>
    <ul>
      <li><a href="${downloadLinks.windows}">Windows Download</a></li>
      <li><a href="${downloadLinks.macos}">macOS Download</a></li>
      <li><a href="${downloadLinks.linux}">Linux Download</a></li>
    </ul>
  `;

  await mailer.sendMail({
    to: customerEmail,
    subject: 'Your Cloudigan Download Links',
    html: emailHtml
  });
}
```

---

## Step 6: Deploy to STANDBY Container

```bash
# Copy OAuth mailer module
scp /Users/cory/Projects/homelab-nexus/scripts/cloudigan-api/m365-oauth-mailer.js root@10.92.3.182:/opt/cloudigan-api/

# SSH to STANDBY
ssh root@10.92.3.182

# Add environment variables
cd /opt/cloudigan-api
cat >> .env << EOF
AZURE_CLIENT_ID=<your_client_id>
AZURE_TENANT_ID=<your_tenant_id>
AZURE_CLIENT_SECRET=<your_client_secret>
EMAIL_FROM=noreply@cloudigan.com
EMAIL_FROM_NAME=Cloudigan IT Solutions
EOF

# Restart service
systemctl restart cloudigan-api

# Check logs
journalctl -u cloudigan-api -f
```

---

## Step 7: Test Email Sending

```bash
# Test from STANDBY container
ssh root@10.92.3.182

# Create test script
cat > /tmp/test-email.js << 'EOF'
const M365OAuthMailer = require('/opt/cloudigan-api/m365-oauth-mailer');
require('dotenv').config({ path: '/opt/cloudigan-api/.env' });

const mailer = new M365OAuthMailer({
  clientId: process.env.AZURE_CLIENT_ID,
  tenantId: process.env.AZURE_TENANT_ID,
  clientSecret: process.env.AZURE_CLIENT_SECRET,
  fromEmail: process.env.EMAIL_FROM,
  fromName: process.env.EMAIL_FROM_NAME
});

mailer.sendMail({
  to: 'cory@cloudigan.com',
  subject: 'Test Email from Cloudigan API',
  html: '<h1>Test Email</h1><p>OAuth2 email sending is working!</p>'
}).then(() => {
  console.log('✅ Email sent successfully');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Email failed:', error.message);
  process.exit(1);
});
EOF

# Run test
node /tmp/test-email.js
```

---

## Troubleshooting

### Error: "Insufficient privileges to complete the operation"
- Make sure you granted **admin consent** for Mail.Send permission
- Check that you selected **Application permissions**, not Delegated

### Error: "Invalid client secret"
- The client secret may have expired
- Create a new client secret in Azure AD
- Update the AZURE_CLIENT_SECRET environment variable

### Error: "Tenant does not have a SPO license"
- This error is unrelated to email - ignore it
- Mail.Send permission doesn't require SharePoint

### Email not received
- Check spam/junk folder
- Verify the sender email exists in M365
- Check Azure AD sign-in logs for the app

---

## Security Best Practices

1. **Rotate client secrets regularly** (every 6-12 months)
2. **Use least privilege** - only grant Mail.Send permission
3. **Monitor app usage** in Azure AD sign-in logs
4. **Store secrets securely** - never commit to git
5. **Use separate apps** for dev/staging/production

---

## Next Steps

Once OAuth2 email is working:
1. ✅ Test with Stripe test checkout
2. ✅ Verify download links in email
3. ✅ Switch HAProxy traffic to STANDBY
4. ✅ Monitor production email sending

---

**Status:** Ready to configure Azure AD app registration
