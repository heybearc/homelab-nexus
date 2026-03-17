#!/bin/bash
# Blue-Green Deployment for Cloudigan API
# Clones LIVE container to create STANDBY, deploys changes, and switches traffic

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LIVE_CONTAINER="10.92.3.181"
STANDBY_CONTAINER="10.92.3.182"
HAPROXY_VIP="10.92.3.33"
APP_DIR="/opt/cloudigan-api"
SERVICE_NAME="cloudigan-api"

# Function to print colored messages
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check container health
check_health() {
    local container_ip=$1
    local max_attempts=10
    local attempt=1
    
    print_info "Checking health of $container_ip..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://${container_ip}:3000/health > /dev/null 2>&1; then
            print_success "Container $container_ip is healthy"
            return 0
        fi
        print_warning "Health check attempt $attempt/$max_attempts failed, retrying..."
        sleep 3
        ((attempt++))
    done
    
    print_error "Container $container_ip failed health check after $max_attempts attempts"
    return 1
}

# Function to get current LIVE container from HAProxy
get_current_live() {
    print_info "Querying HAProxy for current LIVE container..."
    
    # Check HAProxy stats or config to determine which is LIVE
    # For now, we'll use a simple approach - check which backend is active
    local haproxy_config=$(ssh root@${HAPROXY_VIP} "grep -A 5 'use_backend cloudigan_api' /etc/haproxy/haproxy.cfg" 2>/dev/null || echo "")
    
    if echo "$haproxy_config" | grep -q "cloudigan_api_blue"; then
        echo "blue"
    elif echo "$haproxy_config" | grep -q "cloudigan_api_green"; then
        echo "green"
    else
        # Default to blue if can't determine
        echo "blue"
    fi
}

# Function to determine STANDBY container
get_standby_container() {
    local current_live=$1
    
    if [ "$current_live" == "blue" ]; then
        echo "green"
    else
        echo "blue"
    fi
}

# Function to clone LIVE to STANDBY using Proxmox
clone_live_to_standby() {
    local live_ctid=$1
    local standby_ctid=$2
    
    print_info "Cloning CT${live_ctid} to CT${standby_ctid}..."
    
    # Stop STANDBY if it exists
    ssh root@pve "pct stop ${standby_ctid} || true" 2>/dev/null
    
    # Clone the container
    ssh root@pve "pct clone ${live_ctid} ${standby_ctid} --full --hostname cloudigan-api-standby"
    
    print_success "Container cloned successfully"
}

# Function to update STANDBY with new code
update_standby() {
    local standby_ip=$1
    
    print_info "Updating STANDBY container with new code..."
    
    # Start STANDBY container
    ssh root@${standby_ip} "systemctl start ${SERVICE_NAME}" || true
    
    # Wait for container to be ready
    sleep 5
    
    # Copy updated files (if any changes)
    # For SendGrid integration, we need to update webhook-handler.js
    
    # Update .env with SendGrid configuration
    if [ ! -z "$SENDGRID_API_KEY" ]; then
        print_info "Adding SendGrid configuration..."
        ssh root@${standby_ip} "grep -q 'SENDGRID_API_KEY' ${APP_DIR}/.env || echo 'SENDGRID_API_KEY=${SENDGRID_API_KEY}' >> ${APP_DIR}/.env"
        ssh root@${standby_ip} "grep -q 'SENDGRID_FROM_EMAIL' ${APP_DIR}/.env || echo 'SENDGRID_FROM_EMAIL=noreply@cloudigan.com' >> ${APP_DIR}/.env"
    fi
    
    # Restart service to pick up changes
    ssh root@${standby_ip} "systemctl restart ${SERVICE_NAME}"
    
    sleep 3
    
    print_success "STANDBY updated successfully"
}

# Function to switch HAProxy traffic
switch_haproxy_traffic() {
    local new_live=$1
    
    print_info "Switching HAProxy traffic to $new_live..."
    
    # Backup current config
    ssh root@${HAPROXY_VIP} "cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup-$(date +%Y%m%d-%H%M%S)"
    
    # Update routing to point to new LIVE
    if [ "$new_live" == "blue" ]; then
        ssh root@${HAPROXY_VIP} "sed -i 's/use_backend cloudigan_api_green/use_backend cloudigan_api_blue/' /etc/haproxy/haproxy.cfg"
    else
        ssh root@${HAPROXY_VIP} "sed -i 's/use_backend cloudigan_api_blue/use_backend cloudigan_api_green/' /etc/haproxy/haproxy.cfg"
    fi
    
    # Test configuration
    ssh root@${HAPROXY_VIP} "haproxy -c -f /etc/haproxy/haproxy.cfg"
    
    # Reload HAProxy (zero downtime)
    ssh root@${HAPROXY_VIP} "systemctl reload haproxy"
    
    print_success "HAProxy traffic switched to $new_live"
}

# Main deployment flow
main() {
    echo ""
    print_info "=== Cloudigan API Blue-Green Deployment ==="
    echo ""
    
    # Step 1: Determine current LIVE/STANDBY
    CURRENT_LIVE=$(get_current_live)
    CURRENT_STANDBY=$(get_standby_container "$CURRENT_LIVE")
    
    print_info "Current LIVE: $CURRENT_LIVE"
    print_info "Current STANDBY: $CURRENT_STANDBY"
    echo ""
    
    # Step 2: Check LIVE health
    if ! check_health "$LIVE_CONTAINER"; then
        print_error "LIVE container is unhealthy! Aborting deployment."
        exit 1
    fi
    echo ""
    
    # Step 3: Clone LIVE to STANDBY (if using clone approach)
    # For now, we'll assume STANDBY already exists and just update it
    # If you want to clone, uncomment the following:
    # clone_live_to_standby 181 182
    
    # Step 4: Update STANDBY with new code
    update_standby "$STANDBY_CONTAINER"
    echo ""
    
    # Step 5: Health check STANDBY
    if ! check_health "$STANDBY_CONTAINER"; then
        print_error "STANDBY container failed health check! Aborting deployment."
        exit 1
    fi
    echo ""
    
    # Step 6: Ask for confirmation before switching
    print_warning "Ready to switch traffic from $CURRENT_LIVE to $CURRENT_STANDBY"
    read -p "Continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
    echo ""
    
    # Step 7: Switch HAProxy traffic
    switch_haproxy_traffic "$CURRENT_STANDBY"
    echo ""
    
    # Step 8: Verify new LIVE is receiving traffic
    sleep 5
    print_info "Verifying new LIVE is receiving traffic..."
    
    if curl -sf https://api.cloudigan.net/health > /dev/null 2>&1; then
        print_success "New LIVE is receiving traffic and healthy!"
    else
        print_error "New LIVE is not responding! Rolling back..."
        switch_haproxy_traffic "$CURRENT_LIVE"
        exit 1
    fi
    echo ""
    
    # Step 9: Success!
    print_success "=== Deployment Complete ==="
    print_success "New LIVE: $CURRENT_STANDBY"
    print_success "New STANDBY: $CURRENT_LIVE"
    echo ""
    print_info "Monitor logs: ssh root@${STANDBY_CONTAINER} 'journalctl -u ${SERVICE_NAME} -f'"
    echo ""
}

# Run main function
main "$@"
