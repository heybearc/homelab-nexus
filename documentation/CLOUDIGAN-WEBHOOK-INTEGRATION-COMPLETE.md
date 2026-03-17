# Cloudigan API Webhook Integration - Complete Implementation Guide

## Overview

This document provides the complete implementation for Option A: Dynamic Thank-You Page + Email Backup.

**Architecture:**
```
Stripe Checkout → Webhook → Datto Site Creation → Wix CMS + SendGrid Email → Customer
```

## Status

✅ **Infrastructure Complete:**
- Container: CT181 @ 10.92.3.181
- DNS: Configured (Wix CNAMEs + DC-01 A records)
- NPM: SSL termination working
- HAProxy: Blue-green routing active
- Webhook: Receiving Stripe events
- Datto: Site creation working
- OAuth: Token cached (83 hours remaining)

✅ **Code Modules Created:**
- `/opt/cloudigan-api/download-links.js` - Generate all platform download links
- `/opt/cloudigan-api/wix-cms.js` - Wix CMS integration
- `/opt/cloudigan-api/sendgrid-email.js` - Email sending
- `/opt/cloudigan-api/webhook-handler.js` - Main webhook (needs update)

⏳ **Pending Setup:**
1. Create Wix CMS collection
2. Get Wix API credentials
3. Get SendGrid API key
4. Update webhook handler
5. Update Stripe checkout success URL
6. Create Wix thank-you page code

---

## Part 1: Wix CMS Collection Setup

### Create Collection in Wix Dashboard

1. Log into your Wix site
2. Go to **CMS** → **Collections**
3. Click **+ New Collection**
4. Name: `CustomerDownloads`
5. Add these fields:

| Field Key | Display Name | Type | Required |
|-----------|--------------|------|----------|
| `sessionId` | Session ID | Text | ✅ Yes |
| `siteUid` | Datto Site UID | Text | ✅ Yes |
| `customerEmail` | Customer Email | Text | ✅ Yes |
| `customerName` | Customer Name | Text | No |
| `windowsDownloadLink` | Windows Download | URL | ✅ Yes |
| `macDownloadLink` | macOS Download | URL | ✅ Yes |
| `linuxDownloadLink` | Linux Download | URL | ✅ Yes |

6. Set **Permissions**:
   - Insert: **Admin**
   - Update: **Admin**
   - Remove: **Admin**
   - Read: **Anyone** ⚠️ (Important - allows public read)

7. Click **Create**

---

## Part 2: Get API Credentials

### Wix API Credentials

1. Go to Wix Dashboard → **Settings** → **API Keys**
2. Create new API key with **CMS** permissions
3. Copy the API Key
4. Get your Site ID from the URL or API

### SendGrid Setup

1. Sign up at https://sendgrid.com (Free tier: 100 emails/day)
2. Go to **Settings** → **API Keys**
3. Create new API key with **Mail Send** permission
4. Copy the API key
5. Verify sender email: **Settings** → **Sender Authentication**

---

## Part 3: Update Container Environment Variables

SSH into the container and update `.env`:

```bash
ssh root@10.92.3.181
nano /opt/cloudigan-api/.env
```

Add these lines (replace with your actual values):

```env
# Wix CMS Configuration
WIX_SITE_ID=your-actual-wix-site-id
WIX_API_KEY=your-actual-wix-api-key

# SendGrid Configuration
SENDGRID_API_KEY=SG.your-actual-sendgrid-api-key
SENDGRID_FROM_EMAIL=noreply@cloudigan.com
```

---

## Part 4: Update Webhook Handler

Create the updated webhook handler on the container:

```bash
ssh root@10.92.3.181
cd /opt/cloudigan-api
cp webhook-handler.js webhook-handler.js.backup
```

Then update the webhook handler to add the new integrations. The key changes:

1. Import new modules at top:
```javascript
const { generateDownloadLinks } = require('./download-links');
const { insertCustomerDownload } = require('./wix-cms');
const { sendWelcomeEmail } = require('./sendgrid-email');
```

2. In the webhook handler, after creating Datto site:
```javascript
// Generate all platform download links
const downloadLinks = generateDownloadLinks(dattoSite.uid);

// Insert into Wix CMS
if (process.env.WIX_API_KEY && process.env.WIX_SITE_ID) {
  await insertCustomerDownload({
    sessionId: session.id,
    siteUid: dattoSite.uid,
    customerEmail: customerData.email,
    customerName: customerData.companyName,
    downloadLinks
  });
}

// Send welcome email
if (process.env.SENDGRID_API_KEY) {
  await sendWelcomeEmail({
    customerEmail: customerData.email,
    customerName: customerData.companyName,
    downloadLinks,
    siteUid: dattoSite.uid
  });
}
```

3. Restart service:
```bash
systemctl restart cloudigan-api
```

---

## Part 5: Update Stripe Checkout

Update your Stripe checkout session creation to include the session ID in the success URL:

```javascript
const session = await stripe.checkout.sessions.create({
  // ... other parameters
  success_url: 'https://www.cloudigan.com/thank-you?session={CHECKOUT_SESSION_ID}',
  cancel_url: 'https://www.cloudigan.com/pricing',
});
```

---

## Part 6: Wix Thank-You Page Code

Add this code to your Wix thank-you page (`/thank-you`):

### Page Code (Backend - `thank-you.js`):

```javascript
import wixData from 'wix-data';
import { getQueryParams } from 'wix-location';

$w.onReady(function () {
  const sessionId = getQueryParams().session;
  
  if (sessionId) {
    // Query CMS for download links
    wixData.query("CustomerDownloads")
      .eq("sessionId", sessionId)
      .find()
      .then((results) => {
        if (results.items.length > 0) {
          const data = results.items[0];
          
          // Display download links
          $w('#windowsButton').link = data.windowsDownloadLink;
          $w('#macButton').link = data.macDownloadLink;
          $w('#linuxButton').link = data.linuxDownloadLink;
          
          // Show customer name
          $w('#customerName').text = data.customerName;
          
          // Show success message
          $w('#downloadSection').show();
          $w('#loadingSection').hide();
        } else {
          $w('#errorSection').show();
          $w('#loadingSection').hide();
        }
      })
      .catch((error) => {
        console.error("Error fetching download links:", error);
        $w('#errorSection').show();
        $w('#loadingSection').hide();
      });
  } else {
    $w('#errorSection').show();
    $w('#loadingSection').hide();
  }
});
```

### Page Elements to Add:

1. **Loading Section** (`#loadingSection`):
   - Text: "Loading your download links..."

2. **Download Section** (`#downloadSection` - initially hidden):
   - Text: "Welcome, {customerName}!"
   - Heading: "Download Your RMM Agent"
   - Button: "Download for Windows" (`#windowsButton`)
   - Button: "Download for macOS" (`#macButton`)
   - Button: "Download for Linux" (`#linuxButton`)
   - Text: "An email with these links has been sent to your inbox."

3. **Error Section** (`#errorSection` - initially hidden):
   - Text: "We're preparing your download links. Please check your email."

---

## Part 7: Testing

### Test the Complete Flow:

1. **Send test webhook from Stripe Dashboard**
2. **Check container logs:**
```bash
ssh root@10.92.3.181
tail -f /opt/cloudigan-api/logs/webhook.log
```

3. **Verify:**
   - ✅ Datto site created
   - ✅ Download links generated (all 3 platforms)
   - ✅ Wix CMS item created
   - ✅ Email sent to customer
   - ✅ Stripe metadata updated

4. **Test thank-you page:**
   - Get session ID from Stripe test
   - Visit: `https://www.cloudigan.com/thank-you?session=cs_test_...`
   - Verify download buttons appear

---

## Architecture Diagram

```
┌─────────────────┐
│  Stripe Checkout│
│   (Customer)    │
└────────┬────────┘
         │
         │ checkout.session.completed
         ▼
┌─────────────────────────────────────────┐
│  Webhook (CT181 @ 10.92.3.181:3000)    │
│  https://api.cloudigan.net/webhook/stripe│
└────────┬────────────────────────────────┘
         │
         ├──► 1. Create Datto Site
         │      └─► Site UID: abc-123
         │
         ├──► 2. Generate Download Links
         │      ├─► Windows: .../windows/abc-123
         │      ├─► macOS: .../macos/abc-123
         │      └─► Linux: .../linux/abc-123
         │
         ├──► 3. Insert Wix CMS Item
         │      └─► Collection: CustomerDownloads
         │          Fields: sessionId, siteUid, links
         │
         ├──► 4. Send SendGrid Email
         │      └─► To: customer@example.com
         │          Subject: Welcome + Download Links
         │
         └──► 5. Update Stripe Metadata
              └─► session.metadata.datto_site_uid
                  session.metadata.*_download

         ┌──────────────────────┐
         │ Stripe redirects to: │
         │ /thank-you?session=  │
         └──────────┬───────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │  Wix Thank-You Page  │
         │  Queries CMS by      │
         │  sessionId           │
         │  Displays download   │
         │  buttons             │
         └──────────────────────┘
```

---

## Benefits of This Solution

✅ **Immediate Access** - Customer sees links on thank-you page
✅ **Email Backup** - Links also sent via email
✅ **Bookmarkable** - Customer can save the URL
✅ **Resendable** - You can resend email if needed
✅ **Trackable** - CMS stores all download records
✅ **Professional** - Seamless UX
✅ **Multi-Platform** - All OS options provided
✅ **Scalable** - Works for high volume

---

## Troubleshooting

### Wix CMS Insert Fails
- Check WIX_API_KEY and WIX_SITE_ID in `.env`
- Verify collection exists and is named exactly `CustomerDownloads`
- Check permissions: Read must be set to "Anyone"

### Email Not Sending
- Verify SENDGRID_API_KEY in `.env`
- Check SendGrid sender authentication
- Review SendGrid dashboard for bounces/blocks

### Thank-You Page Shows Error
- Verify session ID is in URL
- Check CMS query permissions
- Ensure collection has data for that session

### Download Links Don't Work
- Verify Datto site was created successfully
- Check platform extraction from DATTO_API_URL
- Test links manually in browser

---

## Next Steps

1. ✅ Create Wix CMS collection
2. ✅ Get API credentials (Wix + SendGrid)
3. ✅ Update `.env` file
4. ✅ Update webhook handler
5. ✅ Update Stripe checkout success URL
6. ✅ Add code to Wix thank-you page
7. ✅ Test end-to-end flow
8. ✅ Deploy to production

---

## Support

For issues or questions:
- Check container logs: `/opt/cloudigan-api/logs/`
- Review Stripe webhook logs in Dashboard
- Check SendGrid activity feed
- Verify Wix CMS data in Dashboard
