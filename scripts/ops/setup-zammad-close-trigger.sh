#!/usr/bin/env bash
# Configure Zammad trigger: ticket closed → n8n → Vikunja task complete
set -euo pipefail

ZAMMAD_URL="${ZAMMAD_URL:-https://support.cloudigan.net}"
ZAMMAD_TOKEN="${ZAMMAD_API_TOKEN:-${ZAMMAD_TOKEN:-}}"
N8N_WEBHOOK="${N8N_ZAMMAD_CLOSE_WEBHOOK:-https://flows.cloudigan.net/webhook/zammad-ticket-closed}"

if [[ -z "$ZAMMAD_TOKEN" ]]; then
  echo "Set ZAMMAD_API_TOKEN (Zammad → Profile → Token Access)" >&2
  exit 1
fi

auth=(-H "Authorization: Token token=${ZAMMAD_TOKEN}" -H "Content-Type: application/json")

echo "Creating Zammad webhook for ticket close…"
webhook_payload=$(cat <<EOF
{
  "name": "n8n Vikunja Task Complete",
  "endpoint": "${N8N_WEBHOOK}",
  "signature_token": "",
  "ssl_verify": true,
  "active": true
}
EOF
)

webhook_id=$(curl -sf "${auth[@]}" "${ZAMMAD_URL}/api/v1/webhooks" -d "$webhook_payload" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)

if [[ -z "$webhook_id" ]]; then
  echo "Webhook may already exist — searching…"
  webhook_id=$(curl -sf "${auth[@]}" "${ZAMMAD_URL}/api/v1/webhooks" | python3 -c "
import sys,json
for w in json.load(sys.stdin):
    if 'Vikunja Task Complete' in w.get('name',''):
        print(w['id']); break
")
fi

if [[ -z "$webhook_id" ]]; then
  echo "Failed to create/find webhook" >&2
  exit 1
fi
echo "Webhook ID: $webhook_id"

echo "Creating trigger: ticket closed → webhook…"
trigger_payload=$(cat <<EOF
{
  "name": "Complete Vikunja Task on Ticket Close",
  "condition": {
    "ticket.state_id": {
      "operator": "is",
      "value": "4"
    },
    "ticket.action": {
      "operator": "is",
      "value": "update"
    }
  },
  "perform": {
    "notification.webhook": {
      "webhook_id": "${webhook_id}"
    }
  },
  "active": true
}
EOF
)

curl -sf "${auth[@]}" -X POST "${ZAMMAD_URL}/api/v1/triggers" -d "$trigger_payload" | python3 -m json.tool
echo "✓ Zammad close → Vikunja sync trigger configured"
