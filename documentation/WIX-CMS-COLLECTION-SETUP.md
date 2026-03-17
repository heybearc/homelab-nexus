# Wix CMS Collection Setup - Quick Guide

## Create CustomerDownloads Collection

### Step 1: Access Wix CMS
1. Go to https://manage.wix.com/dashboard/e1c7c474-4d12-462d-b03a-6ad2fc003e59/home
2. Click **CMS** in the left sidebar
3. Click **+ New Collection**

### Step 2: Basic Settings
- **Collection Name:** `CustomerDownloads`
- **Display Name:** Customer Downloads

### Step 3: Add Fields

Click **Add Field** for each of these:

| Field Name | Field Key | Type | Required | Description |
|------------|-----------|------|----------|-------------|
| Session ID | `sessionId` | Text | ✅ Yes | Stripe checkout session ID |
| Datto Site UID | `siteUid` | Text | ✅ Yes | Datto RMM site unique identifier |
| Customer Email | `customerEmail` | Text | ✅ Yes | Customer email address |
| Customer Name | `customerName` | Text | ❌ No | Customer or company name |
| Windows Download Link | `windowsDownloadLink` | URL | ✅ Yes | Windows agent download URL |
| macOS Download Link | `macDownloadLink` | URL | ✅ Yes | macOS agent download URL |
| Linux Download Link | `linuxDownloadLink` | URL | ✅ Yes | Linux agent download URL |

### Step 4: Set Permissions

**CRITICAL:** Set these permissions:
- **Who can add content:** Site Admin
- **Who can update content:** Site Admin  
- **Who can delete content:** Site Admin
- **Who can view content:** Anyone ⚠️ **IMPORTANT - Must be "Anyone" for public access**

### Step 5: Save Collection

Click **Create** or **Save**

---

## Verify Collection Created

After creating, verify the collection exists:
1. Go to CMS → Collections
2. You should see "CustomerDownloads" in the list
3. Click on it to verify all fields are present

---

## Next Steps

Once the collection is created:

1. ✅ Wix API credentials already configured in container
2. ✅ Webhook handler already updated
3. ⏳ Get SendGrid API key (optional - for email backup)
4. ⏳ Test webhook with Stripe

---

## Test Without SendGrid (Email Optional)

You can test the Wix CMS integration immediately without SendGrid:

1. Send test webhook from Stripe Dashboard
2. Check container logs:
   ```bash
   ssh root@10.92.3.181 'tail -f /opt/cloudigan-api/logs/webhook.log'
   ```
3. Look for:
   - ✅ Datto site created
   - ✅ Download links generated
   - ✅ Wix CMS item created
   - ℹ️ SendGrid not configured - skipping email (expected)

4. Verify in Wix CMS:
   - Go to CMS → CustomerDownloads
   - You should see a new entry with the session ID and download links

---

## Current Status

✅ **Ready to test:**
- Container: Running with Wix credentials
- Webhook: Updated with Wix CMS integration
- Datto: Working and creating sites
- Download Links: Generating all 3 platforms

⏳ **Optional (can add later):**
- SendGrid API key for email backup
- Wix thank-you page code for dynamic display

**You can test the Wix CMS integration right now!**
