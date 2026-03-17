#!/bin/bash
# Integrate Cloudigan API with Homelab Blue-Green MCP Server

set -e

echo "=== Integrating Cloudigan API with Homelab MCP ==="
echo ""

# Configuration
MCP_SERVER_PATH="/Users/cory/Projects/Cloudy-Work/shared/mcp-servers/homelab-blue-green-mcp"
CLOUDIGAN_CONFIG="cloudigan-api"

echo "Step 1: Locating homelab MCP server..."
if [ ! -d "$MCP_SERVER_PATH" ]; then
    echo "❌ MCP server not found at: $MCP_SERVER_PATH"
    echo ""
    echo "Please provide the correct path to the homelab MCP server:"
    read -p "Path: " MCP_SERVER_PATH
    
    if [ ! -d "$MCP_SERVER_PATH" ]; then
        echo "❌ Path not found. Exiting."
        exit 1
    fi
fi

echo "✅ Found MCP server at: $MCP_SERVER_PATH"
echo ""

echo "Step 2: Cloudigan API Configuration"
echo "-----------------------------------"
echo ""
echo "Blue (LIVE):"
echo "  - Container: CT181"
echo "  - IP: 10.92.3.181"
echo "  - Name: cloudigan-api-blue"
echo ""
echo "Green (STANDBY):"
echo "  - Container: CT182"
echo "  - IP: 10.92.3.182"
echo "  - Name: cloudigan-api-green"
echo ""
echo "HAProxy:"
echo "  - VIP: 10.92.3.33"
echo "  - Backend: cloudigan_api"
echo "  - Config: /etc/haproxy/haproxy.cfg"
echo ""
echo "Service:"
echo "  - Name: cloudigan-api.service"
echo "  - Port: 3000"
echo "  - Health: /health"
echo ""

read -p "Add this configuration to the MCP server? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Configuration cancelled"
    exit 0
fi

echo ""
echo "Step 3: Configuration to add to MCP server"
echo "------------------------------------------"
echo ""

cat << 'EOF'
# Add to apps configuration:

'cloudigan-api': {
    'name': 'Cloudigan API',
    'blue': {
        'ctid': 181,
        'ip': '10.92.3.181',
        'hostname': 'cloudigan-api-blue'
    },
    'green': {
        'ctid': 182,
        'ip': '10.92.3.182',
        'hostname': 'cloudigan-api-green'
    },
    'haproxy': {
        'vip': '10.92.3.33',
        'backend_blue': 'cloudigan_api_blue',
        'backend_green': 'cloudigan_api_green',
        'config_path': '/etc/haproxy/haproxy.cfg',
        'acl_name': 'is_cloudigan_api'
    },
    'service': {
        'name': 'cloudigan-api.service',
        'port': 3000,
        'health_endpoint': '/health'
    },
    'monitoring': {
        'enabled': True,
        'check_interval': 30
    }
}
EOF

echo ""
echo "Step 4: Manual Integration Required"
echo "-----------------------------------"
echo ""
echo "The MCP server source is outside this workspace."
echo "Please manually add the configuration above to:"
echo "  $MCP_SERVER_PATH"
echo ""
echo "After adding the configuration:"
echo "  1. Restart the MCP server"
echo "  2. Test with: mcp0_get_deployment_status(app='cloudigan-api')"
echo "  3. Verify health checks are working"
echo "  4. Use mcp0_switch_traffic(app='cloudigan-api') to switch"
echo ""
echo "✅ Configuration details saved to: /tmp/cloudigan-mcp-config.txt"

cat << 'EOF' > /tmp/cloudigan-mcp-config.txt
Cloudigan API - Homelab MCP Configuration

Add to apps dictionary:

'cloudigan-api': {
    'name': 'Cloudigan API',
    'blue': {
        'ctid': 181,
        'ip': '10.92.3.181',
        'hostname': 'cloudigan-api-blue'
    },
    'green': {
        'ctid': 182,
        'ip': '10.92.3.182',
        'hostname': 'cloudigan-api-green'
    },
    'haproxy': {
        'vip': '10.92.3.33',
        'backend_blue': 'cloudigan_api_blue',
        'backend_green': 'cloudigan_api_green',
        'config_path': '/etc/haproxy/haproxy.cfg',
        'acl_name': 'is_cloudigan_api'
    },
    'service': {
        'name': 'cloudigan-api.service',
        'port': 3000,
        'health_endpoint': '/health'
    },
    'monitoring': {
        'enabled': True,
        'check_interval': 30
    }
}

HAProxy Backend Names:
- Blue: cloudigan_api_blue
- Green: cloudigan_api_green

ACL: is_cloudigan_api
EOF

echo ""
