#!/bin/bash

# Create trigger to notify admin (cory@cloudigan.com) when new tickets are created

curl -X POST \
  -H "Authorization: Token doghcRUPpmvQ5QnzTm011XtdW7qI4jRJUWyjN8oPlLAs_OtVAt2_IKxLNC8hQbhZ" \
  -H "Content-Type: application/json" \
  -d @- \
  https://support.cloudigan.net/api/v1/triggers << 'EOF'
{
  "name": "Notify Admin on New Ticket",
  "condition": {
    "ticket.action": {
      "operator": "is",
      "value": "create"
    },
    "article.type_id": {
      "operator": "is",
      "value": ["1", "5", "11"]
    },
    "article.sender_id": {
      "operator": "is",
      "value": ["2"]
    }
  },
  "perform": {
    "notification.email": {
      "recipient": "cory@cloudigan.com",
      "subject": "New Support Ticket: #{ticket.title}",
      "body": "<p>A new support ticket has been created:</p>\n<p><br></p>\n<p><b>Ticket ##{ticket.number}</b></p>\n<p><b>From:</b> #{ticket.customer.firstname} #{ticket.customer.lastname} (#{ticket.customer.email})</p>\n<p><b>Subject:</b> #{ticket.title}</p>\n<p><br></p>\n<p><b>Message:</b></p>\n<p>#{article.body}</p>\n<p><br></p>\n<p><a href=\"#{config.http_type}://#{config.fqdn}/#ticket/zoom/#{ticket.id}\">View Ticket</a></p>",
      "internal": "true"
    }
  },
  "active": true,
  "disable_notification": false
}
EOF
