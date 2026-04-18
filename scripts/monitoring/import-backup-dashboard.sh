#!/bin/bash
# Import Proxmox Backup Dashboard into Grafana
# Usage: ./import-backup-dashboard.sh

set -e

GRAFANA_URL="https://grafana.cloudigan.net"
GRAFANA_USER="admin"
GRAFANA_PASS="Cloudy_92!"
DASHBOARD_FILE="proxmox-backup-dashboard.json"

# Check if dashboard file exists
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "❌ Dashboard file not found: $DASHBOARD_FILE"
    exit 1
fi

echo "📊 Importing Proxmox Backup Dashboard to Grafana..."
echo "URL: $GRAFANA_URL"

# Import dashboard
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -d @"$DASHBOARD_FILE" \
    "$GRAFANA_URL/api/dashboards/db")

# Check response
if echo "$RESPONSE" | grep -q '"status":"success"'; then
    DASHBOARD_ID=$(echo "$RESPONSE" | jq -r '.id')
    DASHBOARD_UID=$(echo "$RESPONSE" | jq -r '.uid')
    DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.url')
    
    echo "✅ Dashboard imported successfully!"
    echo ""
    echo "Dashboard Details:"
    echo "  ID: $DASHBOARD_ID"
    echo "  UID: $DASHBOARD_UID"
    echo "  URL: $GRAFANA_URL$DASHBOARD_URL"
    echo ""
    echo "🔗 Access dashboard at: $GRAFANA_URL$DASHBOARD_URL"
else
    echo "❌ Failed to import dashboard"
    echo "Response: $RESPONSE"
    exit 1
fi
