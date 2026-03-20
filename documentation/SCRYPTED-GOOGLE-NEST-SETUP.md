# Scrypted - Google Nest Camera Setup Guide

**Date:** 2026-03-20  
**Scrypted Instance:** https://scrypted.cloudigan.net  
**Container:** CT180 (10.92.3.15)

---

## Prerequisites

- ✅ Scrypted NVR installed and accessible
- ✅ Google Nest cameras on your Google account
- ⏳ Google Cloud account (free tier is fine)
- ⏳ Credit card for Google Cloud verification (won't be charged for this)

---

## Step 1: Install Google Device Access Plugin

1. Go to: https://scrypted.cloudigan.net
2. Click **Plugins** in left sidebar
3. Search for: `google`
4. Find **@scrypted/google-device-access**
5. Click **INSTALL** button
6. Wait for installation to complete

---

## Step 2: Create Google Cloud Project

### 2.1 Access Google Cloud Console

1. Go to: https://console.cloud.google.com/
2. Sign in with your Google account (same one with Nest cameras)

### 2.2 Create New Project

1. Click the project dropdown at the top
2. Click **NEW PROJECT**
3. Enter project details:
   - **Project name:** `Scrypted NVR`
   - **Organization:** Leave as default
4. Click **CREATE**
5. Wait for project creation (takes ~30 seconds)
6. Select the new project from the dropdown

### 2.3 Enable Smart Device Management API

1. Go to: https://console.cloud.google.com/apis/library
2. Search for: `Smart Device Management API`
3. Click on it
4. Click **ENABLE**
5. Wait for API to be enabled

### 2.4 Create OAuth 2.0 Credentials

1. Go to: https://console.cloud.google.com/apis/credentials
2. Click **+ CREATE CREDENTIALS** at the top
3. Select **OAuth client ID**

**If prompted to configure consent screen:**
1. Click **CONFIGURE CONSENT SCREEN**
2. Select **External** (unless you have Google Workspace)
3. Click **CREATE**
4. Fill in required fields:
   - **App name:** `Scrypted NVR`
   - **User support email:** Your email
   - **Developer contact:** Your email
5. Click **SAVE AND CONTINUE**
6. Skip **Scopes** (click SAVE AND CONTINUE)
7. Add test users:
   - Click **+ ADD USERS**
   - Enter your Google account email
   - Click **ADD**
8. Click **SAVE AND CONTINUE**
9. Click **BACK TO DASHBOARD**

**Now create the OAuth client:**
1. Go back to: https://console.cloud.google.com/apis/credentials
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Select **Application type:** Web application
4. Enter name: `Scrypted`
5. Under **Authorized redirect URIs**, click **+ ADD URI**
6. Enter: `https://scrypted.cloudigan.net/endpoint/@scrypted/google-device-access/public/`
   - ⚠️ **Important:** Include the trailing slash!
7. Click **CREATE**
8. **SAVE THESE CREDENTIALS:**
   - **Client ID:** (starts with something like `123456789-abc.apps.googleusercontent.com`)
   - **Client Secret:** (random string)
   - Keep this window open or copy them somewhere safe!

---

## Step 3: Set Up Device Access Console

### 3.1 Register for Device Access

1. Go to: https://console.nest.google.com/device-access/
2. Accept the Terms of Service
3. Click **Go to registration**
4. Pay the **one-time $5 fee** (required by Google)
   - This is a Google requirement, not Scrypted
   - It's a one-time fee, not recurring
5. Complete payment

### 3.2 Create Device Access Project

1. After payment, you'll be at the Device Access Console
2. Click **Create project**
3. Enter project details:
   - **Project name:** `Scrypted NVR`
4. Click **Next**
5. Enter OAuth Client ID from Step 2.4:
   - Paste the **Client ID** you saved earlier
6. Click **Next**
7. Click **Enable events** (optional but recommended)
8. Click **Create project**
9. **SAVE THE PROJECT ID:**
   - It looks like: `project-id-abc123def456`
   - You'll need this in Scrypted

---

## Step 4: Configure Scrypted Plugin

### 4.1 Access Plugin Settings

1. Go to: https://scrypted.cloudigan.net
2. Click **Plugins** in left sidebar
3. Find **Google Device Access**
4. Click the **Settings** icon (gear icon)

### 4.2 Enter Credentials

You'll need to enter three things:

1. **OAuth Client ID:** (from Step 2.4)
   - Paste the Client ID from Google Cloud Console
   
2. **OAuth Client Secret:** (from Step 2.4)
   - Paste the Client Secret from Google Cloud Console
   
3. **Device Access Project ID:** (from Step 3.2)
   - Paste the Project ID from Device Access Console

4. Click **SAVE**

### 4.3 Authorize Scrypted

1. After saving, click **Login with Google** button
2. You'll be redirected to Google
3. Sign in with your Google account (if not already)
4. You may see a warning: "Google hasn't verified this app"
   - This is normal for apps in testing mode
   - Click **Advanced**
   - Click **Go to Scrypted NVR (unsafe)**
5. Review permissions and click **Allow**
6. You'll be redirected back to Scrypted

### 4.4 Discover Cameras

1. After authorization, Scrypted will automatically discover your Nest cameras
2. They'll appear in the **Devices** list
3. Each camera will show up with its name from the Google Home app

---

## Step 5: Configure Cameras

### 5.1 Test Camera Streams

1. Click on a camera in the device list
2. Click **Console** tab
3. You should see camera info and available streams
4. Click **Preview** to test the video stream

### 5.2 Enable Recording (Optional)

**To record camera footage:**

1. Install **Scrypted NVR** plugin (if not already installed):
   - Go to **Plugins**
   - Search for `nvr`
   - Install **@scrypted/nvr**

2. For each camera:
   - Click the camera
   - Go to **Extensions** tab
   - Enable **Scrypted NVR**
   - Configure recording:
     - **Mode:** Continuous or Motion
     - **Retention:** Days to keep recordings
     - **Storage:** Local or network storage

### 5.3 Set Up Storage (Recommended)

**Mount TrueNAS for recordings:**

```bash
# SSH into Scrypted container
ssh root@10.92.3.15

# Create mount point
mkdir -p /mnt/recordings

# Add NFS mount (adjust IP and path for your TrueNAS)
echo "10.92.0.3:/mnt/media-pool/camera-recordings /mnt/recordings nfs defaults 0 0" >> /etc/fstab

# Mount it
mount -a

# Verify
df -h | grep recordings
```

**Configure Scrypted to use it:**
1. Go to **Scrypted NVR** plugin settings
2. Set **Recording Path:** `/mnt/recordings`
3. Click **SAVE**

---

## Troubleshooting

### "Google hasn't verified this app"

**This is normal!** Your OAuth app is in testing mode. Options:

1. **Use it as-is** (click Advanced → Go to app)
2. **Publish the app** (not necessary for personal use)
3. **Add yourself as test user** (already done in Step 2.4)

### Cameras Not Appearing

1. Check that cameras are online in Google Home app
2. Verify OAuth credentials are correct
3. Check Scrypted logs:
   - Click **Plugins** → **Google Device Access**
   - Click **Console** tab
   - Look for error messages

### "Invalid redirect URI"

Make sure the redirect URI in Google Cloud Console exactly matches:
```
https://scrypted.cloudigan.net/endpoint/@scrypted/google-device-access/public/
```
- Must include `https://`
- Must include trailing `/`
- Must match your Scrypted domain

### Streams Not Loading

1. Check your network allows outbound connections to Google
2. Verify cameras have good internet connection
3. Try restarting Scrypted:
   ```bash
   ssh root@10.92.3.15
   systemctl restart scrypted
   ```

---

## Additional Features

### HomeKit Integration

To add cameras to Apple Home:

1. Install **HomeKit** plugin in Scrypted
2. For each camera:
   - Click camera
   - Go to **Extensions**
   - Enable **HomeKit**
3. Scan QR code in Apple Home app

### Motion Detection Alerts

1. Install **Notifier** plugin
2. Configure notification service (email, Pushover, etc.)
3. For each camera:
   - Enable motion detection
   - Set up notification rules

### Remote Access

Your Scrypted is already accessible remotely via:
- **URL:** https://scrypted.cloudigan.net
- **SSL:** Let's Encrypt certificate via NPM
- **Access:** From anywhere with internet

---

## Summary Checklist

- [ ] Install Google Device Access plugin in Scrypted
- [ ] Create Google Cloud Project
- [ ] Enable Smart Device Management API
- [ ] Create OAuth 2.0 credentials
- [ ] Pay $5 Device Access fee (one-time)
- [ ] Create Device Access project
- [ ] Configure plugin with credentials
- [ ] Authorize Scrypted with Google
- [ ] Verify cameras appear
- [ ] Test camera streams
- [ ] (Optional) Set up recording storage
- [ ] (Optional) Enable NVR recording

---

## Credentials Reference

**Save these for future reference:**

```
Google Cloud Project: Scrypted NVR
OAuth Client ID: [YOUR_CLIENT_ID].apps.googleusercontent.com
OAuth Client Secret: [YOUR_CLIENT_SECRET]
Device Access Project ID: [YOUR_PROJECT_ID]

Redirect URI: https://scrypted.cloudigan.net/endpoint/@scrypted/google-device-access/public/
```

---

## Cost Summary

- **Google Cloud:** Free (using free tier)
- **Device Access:** $5 one-time fee (required by Google)
- **Scrypted:** Free (open source)
- **Total:** $5 one-time

---

## Support Resources

- **Scrypted Docs:** https://docs.scrypted.app/
- **Google Device Access:** https://developers.google.com/nest/device-access
- **Scrypted Discord:** https://discord.gg/DcFzmBHYGq

---

## Next Steps After Setup

1. Configure recording schedules
2. Set up motion detection zones
3. Configure retention policies
4. Add HomeKit integration (if using Apple devices)
5. Set up notifications for motion events
6. Create automation rules
