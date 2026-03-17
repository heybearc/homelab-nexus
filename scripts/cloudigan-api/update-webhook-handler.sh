#!/bin/bash
# Update Cloudigan API Webhook Handler with Wix CMS and SendGrid Integration

set -e

CONTAINER_IP="10.92.3.181"
APP_DIR="/opt/cloudigan-api"

echo "🔄 Updating webhook handler with Wix CMS and SendGrid integration..."

# Backup current webhook handler
ssh root@${CONTAINER_IP} "cp ${APP_DIR}/webhook-handler.js ${APP_DIR}/webhook-handler.js.backup-$(date +%Y%m%d-%H%M%S)"

# Create the updated webhook handler
ssh root@${CONTAINER_IP} "cat > ${APP_DIR}/webhook-handler-new.js" << 'WEBHOOK_EOF'
require("dotenv").config();
const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const dattoAuth = require('./datto-auth');
const { generateDownloadLinks } = require('./download-links');
const { insertCustomerDownload } = require('./wix-cms');
const { sendWelcomeEmail } = require('./sendgrid-email');

const app = express();

const DATTO_CONFIG = {
  apiUrl: process.env.DATTO_API_URL,
  apiKey: process.env.DATTO_API_KEY,
  apiSecretKey: process.env.DATTO_API_SECRET_KEY,
};

async function createDattoSite(customerName, customerEmail) {
  try {
    const siteData = await dattoAuth.makeAuthenticatedRequest('/api/v2/site', {
      method: 'PUT',
      body: JSON.stringify({
        name: customerName,
        description: `Customer: ${customerEmail}`,
        notes: `Created via Stripe integration on ${new Date().toISOString()}`,
      }),
    });

    console.log('Datto site created:', siteData);
    return siteData;
  } catch (error) {
    console.error('Failed to create Datto site:', error.message);
    throw error;
  }
}

app.post('/webhook/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;

    try {
      const customerData = {
        email: session.customer_details.email,
        companyName: session.customer_details.name || session.metadata?.company_name,
        subscriptionId: session.subscription,
        customerId: session.customer,
        sessionId: session.id,
      };

      console.log('Processing subscription for:', customerData.email);

      // 1. Create Datto site
      const dattoSite = await createDattoSite(
        customerData.companyName || customerData.email, 
        customerData.email
      );
      console.log('✅ Created Datto site:', dattoSite.uid);

      // 2. Generate all platform download links
      const downloadLinks = generateDownloadLinks(dattoSite.uid);
      console.log('✅ Generated download links:', downloadLinks);

      // 3. Insert into Wix CMS (if configured)
      if (process.env.WIX_API_KEY && process.env.WIX_SITE_ID) {
        try {
          await insertCustomerDownload({
            sessionId: customerData.sessionId,
            siteUid: dattoSite.uid,
            customerEmail: customerData.email,
            customerName: customerData.companyName || customerData.email,
            downloadLinks
          });
          console.log('✅ Wix CMS item created');
        } catch (error) {
          console.error('⚠️  Wix CMS insert failed (non-critical):', error.message);
        }
      } else {
        console.log('ℹ️  Wix CMS not configured - skipping');
      }

      // 4. Send welcome email (if configured)
      if (process.env.SENDGRID_API_KEY) {
        try {
          await sendWelcomeEmail({
            customerEmail: customerData.email,
            customerName: customerData.companyName || customerData.email,
            downloadLinks,
            siteUid: dattoSite.uid
          });
          console.log('✅ Welcome email sent');
        } catch (error) {
          console.error('⚠️  Email send failed (non-critical):', error.message);
        }
      } else {
        console.log('ℹ️  SendGrid not configured - skipping email');
      }

      // 5. Update Stripe session metadata with download links
      try {
        await stripe.checkout.sessions.update(session.id, {
          metadata: {
            datto_site_uid: dattoSite.uid,
            windows_download: downloadLinks.windows,
            mac_download: downloadLinks.mac,
            linux_download: downloadLinks.linux
          }
        });
        console.log('✅ Stripe metadata updated');
      } catch (error) {
        console.error('⚠️  Stripe metadata update failed:', error.message);
      }

      res.json({ 
        received: true,
        dattoSiteUid: dattoSite.uid,
        downloadLinks 
      });

    } catch (error) {
      console.error('Error processing webhook:', error.message);
      res.status(500).json({ error: 'Internal server error' });
    }
  } else {
    res.json({ received: true });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Webhook server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});
WEBHOOK_EOF

# Replace the old webhook handler
ssh root@${CONTAINER_IP} "mv ${APP_DIR}/webhook-handler-new.js ${APP_DIR}/webhook-handler.js"

# Restart the service
echo "🔄 Restarting cloudigan-api service..."
ssh root@${CONTAINER_IP} "systemctl restart cloudigan-api"

sleep 3

# Check service status
echo "✅ Service status:"
ssh root@${CONTAINER_IP} "systemctl status cloudigan-api --no-pager"

echo ""
echo "✅ Webhook handler updated successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Create Wix CMS collection 'CustomerDownloads'"
echo "2. Add WIX_API_KEY and WIX_SITE_ID to .env"
echo "3. Add SENDGRID_API_KEY to .env"
echo "4. Test with Stripe webhook"
echo ""
echo "📖 See: documentation/CLOUDIGAN-WEBHOOK-INTEGRATION-COMPLETE.md"
