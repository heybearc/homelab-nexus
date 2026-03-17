# Stripe Webhook Setup Guide - Cloudigan API

**Date:** 2026-03-16  
**Service:** Cloudigan API (Stripe → Datto automation)  
**Endpoint:** `https://api.cloudigan.net/webhook/stripe`

---

## Step-by-Step Webhook Creation

### **Step 1: Access Stripe Dashboard**

1. **Open Stripe Dashboard:**
   - **Test Mode:** https://dashboard.stripe.com/test/webhooks
   - **Live Mode:** https://dashboard.stripe.com/webhooks

2. **Ensure you're in the correct mode:**
   - Look for the toggle in the top-left corner
   - Start with **Test mode** for initial testing
   - Switch to **Live mode** once verified

---

### **Step 2: Create Webhook Endpoint**

1. **Click "Add endpoint" button** (or "Create an event destination")

2. **Fill in Endpoint Details:**

   **Endpoint URL:**
   ```
   https://api.cloudigan.net/webhook/stripe
   ```

   **Description:** (Optional but recommended)
   ```
   Cloudigan API - Stripe to Datto RMM automation
   ```

3. **Select Events to Listen:**
   - Click **"Select events"** or **"+ Select events"**
   - In the search box, type: `checkout.session.completed`
   - Check the box next to **`checkout.session.completed`**
   - Click **"Add events"**

4. **API Version:**
   - Use **"Latest API version"** (recommended)
   - Or select your account's default version

5. **Click "Add endpoint"** to save

---

### **Step 3: Get Webhook Signing Secret**

After creating the endpoint, Stripe will show you the endpoint details page.

1. **Locate the "Signing secret" section**
   - It will be in a gray box
   - Format: `whsec_...` (starts with `whsec_`)

2. **Click "Reveal" to show the secret**

3. **Copy the entire secret** (including `whsec_` prefix)
   - Example: `whsec_1234567890abcdefghijklmnopqrstuvwxyz`

4. **IMPORTANT:** Keep this secret secure!
   - This is used to verify webhook authenticity
   - Never commit to git or share publicly

---

### **Step 4: Update Container Environment**

Once you have the webhook signing secret, provide it to update the container's `.env` file:

**Command to update:**
```bash
ssh root@10.92.3.181 'sed -i "s/STRIPE_WEBHOOK_SECRET=.*/STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET_HERE/" /opt/cloudigan-api/.env && systemctl restart cloudigan-api'
```

**Or manually:**
```bash
# SSH to container
ssh root@10.92.3.181

# Edit .env file
nano /opt/cloudigan-api/.env

# Update this line:
STRIPE_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET

# Save and restart service
systemctl restart cloudigan-api
```

---

### **Step 5: Test the Webhook**

#### **Option A: Send Test Event from Dashboard**

1. On the webhook endpoint page, click **"Send test webhook"**
2. Select event type: `checkout.session.completed`
3. Click **"Send test webhook"**
4. Check the webhook logs to see if it was received

#### **Option B: Use Stripe CLI (Recommended)**

```bash
# Install Stripe CLI (if not installed)
brew install stripe/stripe-cli/stripe

# Login to Stripe
stripe login

# Send test checkout.session.completed event
stripe trigger checkout.session.completed
```

#### **Option C: Create Test Checkout Session**

1. Go to **Products** in Stripe Dashboard
2. Create a test product with a price
3. Create a **Payment Link** or **Checkout Session**
4. Complete a test purchase
5. Webhook should fire automatically

---

### **Step 6: Verify Webhook Delivery**

**In Stripe Dashboard:**
1. Go to **Webhooks** → Click your endpoint
2. Click **"Events & logs"** tab
3. You should see recent webhook attempts
4. Green checkmark = Success
5. Red X = Failed (click to see error details)

**In Container Logs:**
```bash
# SSH to container
ssh root@10.92.3.181

# View webhook logs
tail -f /opt/cloudigan-api/logs/webhook.log

# View error logs
tail -f /opt/cloudigan-api/logs/error.log

# View systemd logs
journalctl -u cloudigan-api -f
```

---

## Expected Webhook Payload

When a customer completes checkout, Stripe sends:

```json
{
  "id": "evt_...",
  "object": "event",
  "type": "checkout.session.completed",
  "data": {
    "object": {
      "id": "cs_test_...",
      "object": "checkout.session",
      "customer": "cus_...",
      "customer_email": "customer@example.com",
      "metadata": {
        "company_name": "Example Company"
      },
      "payment_status": "paid",
      "status": "complete"
    }
  }
}
```

---

## Troubleshooting

### **Webhook Not Receiving Events**

1. **Check URL is publicly accessible:**
   ```bash
   curl https://api.cloudigan.net/webhook/stripe
   ```
   - Should return 200 or 405 (method not allowed for GET)
   - Should NOT return timeout or connection refused

2. **Check DNS resolution:**
   ```bash
   nslookup api.cloudigan.net
   ```
   - Should resolve to HAProxy VIP: `10.92.3.33`

3. **Check HAProxy routing:**
   ```bash
   curl http://blue.api.cloudigan.net/health
   ```
   - Should return: `{"status":"ok"}`

4. **Check service is running:**
   ```bash
   ssh root@10.92.3.181 'systemctl status cloudigan-api'
   ```

### **Webhook Signature Verification Failing**

1. **Ensure webhook secret is correct:**
   - Check `.env` file has correct `STRIPE_WEBHOOK_SECRET`
   - Secret should start with `whsec_`

2. **Check application is reading .env:**
   ```bash
   ssh root@10.92.3.181 'cat /opt/cloudigan-api/.env | grep STRIPE_WEBHOOK_SECRET'
   ```

3. **Restart service after updating .env:**
   ```bash
   ssh root@10.92.3.181 'systemctl restart cloudigan-api'
   ```

### **Datto Site Creation Failing**

1. **Check Datto credentials in .env:**
   - `DATTO_API_URL`
   - `DATTO_API_KEY`
   - `DATTO_API_SECRET_KEY`

2. **Check OAuth token generation:**
   ```bash
   ssh root@10.92.3.181 'cat /opt/cloudigan-api/.datto-token.json'
   ```
   - Should exist and have valid token
   - Token auto-refreshes before expiration

3. **Check application logs:**
   ```bash
   ssh root@10.92.3.181 'tail -100 /opt/cloudigan-api/logs/webhook.log'
   ```

---

## Security Best Practices

1. **Always verify webhook signatures**
   - Application already does this via Stripe SDK
   - Never process unverified webhooks

2. **Use HTTPS only**
   - Stripe requires HTTPS for production webhooks
   - Test mode allows HTTP for local testing

3. **Keep secrets secure**
   - Never commit `.env` to git
   - Rotate secrets if compromised
   - Use environment variables in production

4. **Monitor webhook failures**
   - Set up alerts for failed webhooks
   - Stripe will retry failed webhooks automatically
   - After 3 days of failures, Stripe disables the endpoint

---

## Next Steps After Webhook Setup

1. **Test with real Stripe Checkout:**
   - Create test product in Stripe
   - Complete test purchase
   - Verify Datto site created

2. **Configure Wix Integration:**
   - Add Stripe Checkout to Wix website
   - Test end-to-end customer flow

3. **Deploy Green Container:**
   - Repeat deployment for `cloudigan-api-green` (CT182)
   - Test blue-green traffic switching

4. **Switch to Live Mode:**
   - Create webhook in Live mode
   - Update `.env` with live webhook secret
   - Update Stripe API keys to live mode

---

## Reference Links

- **Stripe Webhooks Documentation:** https://docs.stripe.com/webhooks
- **Checkout Session Events:** https://docs.stripe.com/api/events/types#event_types-checkout.session.completed
- **Webhook Best Practices:** https://docs.stripe.com/webhooks/best-practices
- **Stripe CLI:** https://docs.stripe.com/stripe-cli

---

**Status:** Ready for webhook creation  
**Container:** cloudigan-api-blue (CT181) @ 10.92.3.181  
**Endpoint:** https://api.cloudigan.net/webhook/stripe
