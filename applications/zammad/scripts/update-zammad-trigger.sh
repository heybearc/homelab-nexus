#!/bin/bash

# Update Zammad auto-reply trigger to use signature placeholder

curl -X PUT \
  -H "Authorization: Token doghcRUPpmvQ5QnzTm011XtdW7qI4jRJUWyjN8oPlLAs_OtVAt2_IKxLNC8hQbhZ" \
  -H "Content-Type: application/json" \
  -d @- \
  https://support.cloudigan.net/api/v1/triggers/1 << 'EOF'
{
  "perform": {
    "notification.email": {
      "body": "<p>Hello&nbsp;#{ticket.customer.firstname},</p>\n<p><br></p>\n<p>Thanks for reaching out to Cloudigan Support — we've received your request and your ticket <b>[Ticket##{ticket.number}]</b> is now in our system.</p>\n<p><br></p>\n<p>Our team will review and begin working on this shortly. For most requests, you can expect an initial response within <b>4 business hours</b>, in line with your service agreement.</p>\n<p><br></p>\n<p>If your request is time-sensitive or impacting business operations, please reply to this email with <b>URGENT</b> in the subject line so we can prioritize it appropriately.</p>\n<p><br></p>\n<p>As a reminder, requests are handled based on priority and scope. Items outside of your current service coverage or requiring project-level work will be clearly communicated before any additional work is performed.</p>\n<p><br></p>\n<p>We appreciate the opportunity to support your business and keep things running smoothly.</p>\n<p><br></p>\n<p>#{signature}</p>",
      "internal": "false",
      "recipient": ["article_last_sender"],
      "subject": "Ticket Recieved [Ticket##{ticket.number}]",
      "include_attachments": "false"
    }
  }
}
EOF
