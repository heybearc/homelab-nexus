#!/bin/bash
# Configure HAProxy for Cloudigan API Blue-Green Deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
HAPROXY_VIP="10.92.3.33"
BLUE_IP="10.92.3.181"
GREEN_IP="10.92.3.182"

echo ""
print_info "=== HAProxy Blue-Green Configuration ==="
echo ""

# Step 1: Backup current HAProxy config
print_info "Step 1: Backing up current HAProxy configuration..."

BACKUP_FILE="haproxy.cfg.backup-$(date +%Y%m%d-%H%M%S)"
ssh root@${HAPROXY_VIP} "cp /etc/haproxy/haproxy.cfg /etc/haproxy/${BACKUP_FILE}"

print_success "Backup created: ${BACKUP_FILE}"
echo ""

# Step 2: Add backend configurations
print_info "Step 2: Adding Cloudigan API backend configurations..."

ssh root@${HAPROXY_VIP} "cat >> /etc/haproxy/haproxy.cfg" << 'EOF'

#---------------------------------------------------------------------
# Cloudigan API - Blue-Green Backends
#---------------------------------------------------------------------

backend cloudigan_api_blue
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    http-request set-header X-Forwarded-Host %[req.hdr(host)]
    server blue1 10.92.3.181:3000 check inter 5s fall 3 rise 2

backend cloudigan_api_green
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    http-request set-header X-Forwarded-Host %[req.hdr(host)]
    server green1 10.92.3.182:3000 check inter 5s fall 3 rise 2
EOF

print_success "Backend configurations added"
echo ""

# Step 3: Add frontend routing
print_info "Step 3: Adding frontend routing rules..."

# Find the frontend section and add ACLs and routing
ssh root@${HAPROXY_VIP} "sed -i '/^frontend https_frontend/a\\
    # Cloudigan API - Domain ACLs\n\
    acl is_cloudigan_api hdr(host) -i api.cloudigan.net\n\
    acl is_cloudigan_api hdr(host) -i www.api.cloudigan.net\n\
    \n\
    # Cloudigan API - Direct access ACLs\n\
    acl is_cloudigan_blue hdr(host) -i blue.api.cloudigan.net\n\
    acl is_cloudigan_green hdr(host) -i green.api.cloudigan.net\n\
    \n\
    # Cloudigan API - Main routing (Blue is LIVE initially)\n\
    use_backend cloudigan_api_blue if is_cloudigan_api\n\
    \n\
    # Cloudigan API - Direct access routing\n\
    use_backend cloudigan_api_blue if is_cloudigan_blue\n\
    use_backend cloudigan_api_green if is_cloudigan_green' /etc/haproxy/haproxy.cfg"

print_success "Frontend routing rules added"
echo ""

# Step 4: Test configuration
print_info "Step 4: Testing HAProxy configuration..."

if ssh root@${HAPROXY_VIP} "haproxy -c -f /etc/haproxy/haproxy.cfg"; then
    print_success "Configuration is valid"
else
    print_error "Configuration has errors!"
    print_info "Restoring backup..."
    ssh root@${HAPROXY_VIP} "cp /etc/haproxy/${BACKUP_FILE} /etc/haproxy/haproxy.cfg"
    exit 1
fi
echo ""

# Step 5: Reload HAProxy
print_info "Step 5: Reloading HAProxy (zero downtime)..."

ssh root@${HAPROXY_VIP} "systemctl reload haproxy"

sleep 2

if ssh root@${HAPROXY_VIP} "systemctl is-active haproxy" | grep -q "active"; then
    print_success "HAProxy reloaded successfully"
else
    print_error "HAProxy failed to reload!"
    exit 1
fi
echo ""

# Step 6: Verify backends
print_info "Step 6: Verifying backend health..."

sleep 5

BACKEND_STATUS=$(ssh root@${HAPROXY_VIP} "echo 'show stat' | socat stdio /var/run/haproxy/admin.sock | grep cloudigan")

if echo "$BACKEND_STATUS" | grep -q "cloudigan_api_blue"; then
    print_success "Blue backend registered"
else
    print_warning "Blue backend not found in stats"
fi

if echo "$BACKEND_STATUS" | grep -q "cloudigan_api_green"; then
    print_success "Green backend registered"
else
    print_warning "Green backend not found in stats"
fi
echo ""

# Step 7: Test routing
print_info "Step 7: Testing routing..."

# Test main domain (should route to blue)
if curl -sf -H "Host: api.cloudigan.net" http://${HAPROXY_VIP}/health > /dev/null 2>&1; then
    print_success "Main domain routing works (api.cloudigan.net → blue)"
else
    print_warning "Main domain routing test failed"
fi

# Test direct blue access
if curl -sf -H "Host: blue.api.cloudigan.net" http://${HAPROXY_VIP}/health > /dev/null 2>&1; then
    print_success "Direct blue access works (blue.api.cloudigan.net)"
else
    print_warning "Direct blue access test failed"
fi

# Test direct green access
if curl -sf -H "Host: green.api.cloudigan.net" http://${HAPROXY_VIP}/health > /dev/null 2>&1; then
    print_success "Direct green access works (green.api.cloudigan.net)"
else
    print_warning "Direct green access test failed"
fi
echo ""

# Summary
print_success "=== HAProxy Configuration Complete ==="
echo ""
print_info "Current Routing:"
echo "  api.cloudigan.net       → Blue (LIVE)"
echo "  blue.api.cloudigan.net  → Blue (direct)"
echo "  green.api.cloudigan.net → Green (direct)"
echo ""
print_info "Backend Health Checks:"
echo "  Endpoint: GET /health"
echo "  Interval: 5 seconds"
echo "  Fail threshold: 3 consecutive failures"
echo "  Rise threshold: 2 consecutive successes"
echo ""
print_info "Next Steps:"
echo "  1. Add SendGrid integration to STANDBY (green)"
echo "  2. Test STANDBY via green.api.cloudigan.net"
echo "  3. Switch traffic to green when ready"
echo ""
print_info "Useful Commands:"
echo "  View HAProxy stats: ssh root@${HAPROXY_VIP} \"echo 'show stat' | socat stdio /var/run/haproxy/admin.sock | grep cloudigan\""
echo "  Test blue:  curl -H 'Host: blue.api.cloudigan.net' http://${HAPROXY_VIP}/health"
echo "  Test green: curl -H 'Host: green.api.cloudigan.net' http://${HAPROXY_VIP}/health"
echo "  Switch to green: Edit /etc/haproxy/haproxy.cfg, change 'use_backend cloudigan_api_blue' to 'use_backend cloudigan_api_green'"
echo ""
