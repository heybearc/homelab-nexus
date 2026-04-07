#!/bin/bash
# Update auto-reply trigger with logo signature embedded

# Get the signature HTML
SIGNATURE=$(curl -s -H "Authorization: Token doghcRUPpmvQ5QnzTm011XtdW7qI4jRJUWyjN8oPlLAs_OtVAt2_IKxLNC8hQbhZ" \
  https://support.cloudigan.net/api/v1/signatures/2 | jq -r '.body')

# Create the email body with signature
BODY="<p>Hello&nbsp;#{ticket.customer.firstname},</p>
<p><br></p>
<p>Thanks for reaching out to Cloudigan Support — we've received your request and your ticket <b>[Ticket##{ticket.number}]</b> is now in our system.</p>
<p><br></p>
<p>Our team will review and begin working on this shortly. For most requests, you can expect an initial response within <b>4 business hours</b>, in line with your service agreement.</p>
<p><br></p>
<p>If your request is time-sensitive or impacting business operations, please reply to this email with <b>URGENT</b> in the subject line so we can prioritize it appropriately.</p>
<p><br></p>
<p>As a reminder, requests are handled based on priority and scope. Items outside of your current service coverage or requiring project-level work will be clearly communicated before any additional work is performed.</p>
<p><br></p>
<p>We appreciate the opportunity to support your business and keep things running smoothly.</p>
<p><br></p>
${SIGNATURE}"

# Update the trigger
curl -X PUT \
  -H "Authorization: Token doghcRUPpmvQ5QnzTm011XtdW7qI4jRJUWyjN8oPlLAs_OtVAt2_IKxLNC8hQbhZ" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg body "$BODY" '{
    perform: {
      "notification.email": {
        body: $body,
        internal: "false",
        recipient: ["article_last_sender"],
        subject: "Ticket Received [Ticket##{ticket.number}]",
        include_attachments: "false"
      }
    }
  }')" \
  https://support.cloudigan.net/api/v1/triggers/1

echo ""
echo "✅ Auto-reply trigger updated with logo signature"
