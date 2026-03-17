# Wix Checkout Confirmation Page Setup Guide

## Overview
Add dynamic download links to your Wix checkout confirmation pages that query the CustomerDownloads CMS collection using the Stripe session ID.

---

## Pages to Update

1. **Business Checkout Confirmation:** `/business/b-checkout-confirmation`
2. **Home Protect Checkout Confirmation:** `/homeprotect/h-checkout-confirmation`

---

## Step 1: Update Stripe Success URLs

First, update your Stripe pricing tables to include the session ID parameter:

### Business Customers
**Current:** `https://www.cloudigan.com/business/b-checkout-confirmation`  
**Update to:** `https://www.cloudigan.com/business/b-checkout-confirmation?session={CHECKOUT_SESSION_ID}`

### Home Protect Customers
**Current:** `https://www.cloudigan.com/homeprotect/h-checkout-confirmation`  
**Update to:** `https://www.cloudigan.com/homeprotect/h-checkout-confirmation?session={CHECKOUT_SESSION_ID}`

**Where to update:**
- Go to Stripe Dashboard → Products → Pricing Tables
- Edit each pricing table
- Update the "Success URL" field
- The `{CHECKOUT_SESSION_ID}` placeholder will be automatically replaced by Stripe

---

## Step 2: Enable Velo (Wix Code)

If not already enabled:

1. Open Wix Editor
2. Click **Dev Mode** button (top bar)
3. Enable **Velo by Wix**
4. This allows you to add custom code to pages

---

## Step 3: Add Page Elements

For **BOTH** checkout confirmation pages, add these elements:

### Loading Section (Initially Visible)
- **Text element**
  - ID: `loadingText`
  - Text: "⏳ Loading your download links..."
  - Style: Center aligned, medium size

### Download Section (Initially Hidden)
- **Container/Box** (to group elements)
  - ID: `downloadSection`
  - Initially hidden (click element → Settings → Show/Hide → Hide on load)

Inside the download section, add:

1. **Welcome Text**
   - ID: `customerName`
   - Text: "Welcome!"
   - Style: Heading 2

2. **Instructions Heading**
   - Text: "Download Your RMM Agent"
   - Style: Heading 3

3. **Windows Download Button**
   - ID: `windowsButton`
   - Text: "🪟 Download for Windows"
   - Link: Leave empty (will be set dynamically)
   - Target: New window
   - Style: Primary button

4. **macOS Download Button**
   - ID: `macButton`
   - Text: "🍎 Download for macOS"
   - Link: Leave empty (will be set dynamically)
   - Target: New window
   - Style: Primary button

5. **Linux Download Button**
   - ID: `linuxButton`
   - Text: "🐧 Download for Linux"
   - Link: Leave empty (will be set dynamically)
   - Target: New window
   - Style: Primary button

6. **Email Reminder Text**
   - Text: "📧 An email with these links has also been sent to your inbox."
   - Style: Small text, gray color

7. **Bookmark Tip Text**
   - Text: "💡 Tip: Bookmark this page for future reference"
   - Style: Small text, italic

### Error Section (Initially Hidden)
- **Container/Box**
  - ID: `errorSection`
  - Initially hidden

Inside error section:
- **Error Text**
  - Text: "We're preparing your download links. Please check your email shortly or contact support if you need assistance."
  - Style: Center aligned

---

## Step 4: Add Page Code

### For Business Checkout Confirmation Page:

1. In Wix Editor, open the page: `/business/b-checkout-confirmation`
2. Click **Dev Mode** → **Code Files** (left panel)
3. Find the page code file (e.g., `b-checkout-confirmation.js`)
4. Replace the entire content with this code:

```javascript
import wixData from 'wix-data';
import wixLocation from 'wix-location';

$w.onReady(function () {
  // Get session ID from URL query parameter
  const sessionId = wixLocation.query.session;
  
  console.log('Session ID from URL:', sessionId);
  
  if (sessionId) {
    // Show loading state
    $w('#loadingText').show();
    $w('#downloadSection').hide();
    $w('#errorSection').hide();
    
    // Query CMS for download links using session ID
    wixData.query("CustomerDownloads")
      .eq("sessionId", sessionId)
      .find()
      .then((results) => {
        console.log('CMS query results:', results);
        
        if (results.items.length > 0) {
          const data = results.items[0];
          
          console.log('Download data found:', data);
          
          // Set download button links
          $w('#windowsButton').link = data.windowsDownloadLink;
          $w('#macButton').link = data.macOsDownloadLink;
          $w('#linuxButton').link = data.linuxDownloadLink;
          
          // Show customer name
          $w('#customerName').text = `Welcome, ${data.customerName}!`;
          
          // Hide loading, show download section
          $w('#loadingText').hide();
          $w('#downloadSection').show();
          
          console.log('Download links displayed successfully');
        } else {
          // No data found - show error
          console.warn('No download data found for session:', sessionId);
          $w('#loadingText').hide();
          $w('#errorSection').show();
        }
      })
      .catch((error) => {
        console.error('Error fetching download links:', error);
        $w('#loadingText').hide();
        $w('#errorSection').show();
      });
  } else {
    // No session ID in URL
    console.error('No session ID found in URL');
    $w('#loadingText').hide();
    $w('#errorSection').show();
  }
});
```

### For Home Protect Checkout Confirmation Page:

1. Open the page: `/homeprotect/h-checkout-confirmation`
2. Click **Dev Mode** → **Code Files**
3. Find the page code file (e.g., `h-checkout-confirmation.js`)
4. Use the **EXACT SAME CODE** as above

---

## Step 5: Set Element Visibility

For **BOTH** pages, ensure:

1. `#loadingText` → **Visible on load** ✅
2. `#downloadSection` → **Hidden on load** ❌
3. `#errorSection` → **Hidden on load** ❌

To set visibility:
- Select element → Settings panel → Show/Hide section → Toggle "Hide on load"

---

## Step 6: Publish Your Site

1. Click **Publish** in top-right corner
2. Wait for publish to complete
3. Your changes are now live

---

## Step 7: Test the Complete Flow

### Test with Stripe Test Mode:

1. Go to your pricing page
2. Click on a pricing table
3. Complete checkout with test card: `4242 4242 4242 4242`
4. After payment, you should be redirected to:
   - `https://www.cloudigan.com/business/b-checkout-confirmation?session=cs_test_...`

5. **Expected behavior:**
   - Page shows "Loading your download links..." briefly
   - Page queries CMS using session ID
   - Download section appears with:
     - "Welcome, [Customer Name]!"
     - Three download buttons (Windows, macOS, Linux)
     - Email reminder text
     - Bookmark tip

6. Click each download button to verify links work

### Troubleshooting:

**If error section shows:**
- Check browser console (F12) for error messages
- Verify session ID is in URL
- Check CMS collection has data for that session ID
- Verify element IDs match exactly (case-sensitive)

**If buttons don't work:**
- Check that button IDs are exactly: `windowsButton`, `macButton`, `linuxButton`
- Verify CMS field names: `windowsDownloadLink`, `macOsDownloadLink`, `linuxDownloadLink`

**To debug:**
- Open browser console (F12)
- Look for console.log messages showing:
  - Session ID from URL
  - CMS query results
  - Download data found

---

## What Happens Behind the Scenes

```
1. Customer completes Stripe checkout
   ↓
2. Stripe redirects to: /b-checkout-confirmation?session=cs_test_...
   ↓
3. Page loads, JavaScript extracts session ID from URL
   ↓
4. Queries Wix CMS: "Find CustomerDownloads where sessionId = cs_test_..."
   ↓
5. CMS returns: {
     customerName: "John Doe",
     windowsDownloadLink: "https://vidal.rmm.datto.com/...",
     macOsDownloadLink: "https://vidal.rmm.datto.com/...",
     linuxDownloadLink: "https://vidal.rmm.datto.com/..."
   }
   ↓
6. JavaScript sets button links and displays download section
   ↓
7. Customer clicks button → Downloads RMM agent
```

---

## CMS Data Flow

The webhook already populates the CMS when a customer checks out:

```javascript
// Webhook creates this data in CMS:
{
  sessionId: "cs_test_a1PwxHV7KN0xnZHwSfx4...",
  dattoSiteUid: "2b6f38e5-3c4c-4c2c-a215-72890351910f",
  customerEmail: "customer@example.com",
  customerName: "John Doe",
  windowsDownloadLink: "https://vidal.rmm.datto.com/download-agent/windows/2b6f38e5...",
  macOsDownloadLink: "https://vidal.rmm.datto.com/download-agent/macos/2b6f38e5...",
  linuxDownloadLink: "https://vidal.rmm.datto.com/download-agent/linux/2b6f38e5..."
}
```

The page code queries this data using the session ID and displays it.

---

## Next Steps After Setup

1. Test with Stripe test mode
2. Verify all download links work
3. Test with real payment (small amount)
4. Monitor for any errors in browser console
5. Optional: Add SendGrid email integration for backup delivery

---

## Support

If you encounter issues:
1. Check browser console for errors
2. Verify CMS collection has data
3. Check element IDs match code
4. Verify Stripe success URL includes `?session={CHECKOUT_SESSION_ID}`
