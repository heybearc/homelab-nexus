#!/bin/bash
# Cloudigan API - Blue-Green Setup using Proxmox MCP
# Clones existing CT181 (LIVE) to create CT182 (STANDBY)

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
LIVE_CTID=181
STANDBY_CTID=182
LIVE_IP="10.92.3.181"
STANDBY_IP="10.92.3.182"
LIVE_NAME="cloudigan-api-blue"
STANDBY_NAME="cloudigan-api-green"
PROXMOX_NODE="pve"

echo ""
print_info "=== Cloudigan API Blue-Green Setup ==="
echo ""

# Step 1: Verify LIVE container exists and is running
print_info "Step 1: Verifying LIVE container CT${LIVE_CTID}..."

if ! ssh root@${PROXMOX_NODE} "pct status ${LIVE_CTID}" | grep -q "running"; then
    print_error "LIVE container CT${LIVE_CTID} is not running!"
    exit 1
fi

print_success "LIVE container CT${LIVE_CTID} is running"
echo ""

# Step 2: Check if STANDBY already exists
print_info "Step 2: Checking for existing STANDBY container..."

if ssh root@${PROXMOX_NODE} "pct status ${STANDBY_CTID}" 2>/dev/null | grep -q "status"; then
    print_warning "STANDBY container CT${STANDBY_CTID} already exists"
    read -p "Delete and recreate? (yes/no): " confirm
    
    if [ "$confirm" == "yes" ]; then
        print_info "Stopping and removing CT${STANDBY_CTID}..."
        ssh root@${PROXMOX_NODE} "pct stop ${STANDBY_CTID} || true"
        sleep 3
        ssh root@${PROXMOX_NODE} "pct destroy ${STANDBY_CTID}"
        print_success "Removed existing STANDBY container"
    else
        print_warning "Keeping existing STANDBY container"
        exit 0
    fi
fi
echo ""

# Step 3: Stop LIVE container temporarily for cloning
print_info "Step 3: Stopping LIVE container for cloning..."
print_warning "This will cause brief downtime (~2-5 minutes)"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_warning "Clone cancelled by user"
    exit 0
fi

ssh root@${PROXMOX_NODE} "pct stop ${LIVE_CTID}"
sleep 5

print_success "LIVE container stopped"
echo ""

# Step 4: Clone LIVE to STANDBY
print_info "Step 4: Cloning CT${LIVE_CTID} to CT${STANDBY_CTID}..."
print_warning "This may take 2-5 minutes depending on container size..."

ssh root@${PROXMOX_NODE} "pct clone ${LIVE_CTID} ${STANDBY_CTID} --full --hostname ${STANDBY_NAME}"

print_success "Container cloned successfully"
echo ""

# Step 5: Restart LIVE container
print_info "Step 5: Restarting LIVE container..."
ssh root@${PROXMOX_NODE} "pct start ${LIVE_CTID}"
sleep 5

# Verify LIVE is back up
if curl -sf http://${LIVE_IP}:3000/health > /dev/null 2>&1; then
    print_success "LIVE container is back online and healthy"
else
    print_warning "LIVE container started but health check pending..."
fi
echo ""

# Step 6: Update STANDBY network configuration
print_info "Step 6: Updating STANDBY network configuration..."

ssh root@${PROXMOX_NODE} "pct set ${STANDBY_CTID} -net0 name=eth0,bridge=vmbr0923,ip=${STANDBY_IP}/24,gw=10.92.3.1"

print_success "Network configuration updated"
echo ""

# Step 7: Start STANDBY container
print_info "Step 7: Starting STANDBY container..."

ssh root@${PROXMOX_NODE} "pct start ${STANDBY_CTID}"

sleep 5

print_success "STANDBY container started"
echo ""

# Step 8: Verify STANDBY is accessible
print_info "Step 8: Verifying STANDBY accessibility..."

max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    if ping -c 1 ${STANDBY_IP} > /dev/null 2>&1; then
        print_success "STANDBY container is reachable at ${STANDBY_IP}"
        break
    fi
    print_warning "Ping attempt $attempt/$max_attempts failed, retrying..."
    sleep 3
    ((attempt++))
done

if [ $attempt -gt $max_attempts ]; then
    print_error "STANDBY container not reachable after $max_attempts attempts"
    exit 1
fi
echo ""

# Step 9: Verify service is running on STANDBY
print_info "Step 9: Verifying cloudigan-api service on STANDBY..."

sleep 5

if ssh root@${STANDBY_IP} "systemctl is-active cloudigan-api" | grep -q "active"; then
    print_success "Service is running on STANDBY"
else
    print_warning "Service not running, attempting to start..."
    ssh root@${STANDBY_IP} "systemctl start cloudigan-api"
    sleep 3
    
    if ssh root@${STANDBY_IP} "systemctl is-active cloudigan-api" | grep -q "active"; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service on STANDBY"
        print_info "Check logs: ssh root@${STANDBY_IP} 'journalctl -u cloudigan-api -n 50'"
        exit 1
    fi
fi
echo ""

# Step 10: Health check STANDBY
print_info "Step 10: Running health check on STANDBY..."

max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -sf http://${STANDBY_IP}:3000/health > /dev/null 2>&1; then
        print_success "STANDBY health check passed"
        break
    fi
    print_warning "Health check attempt $attempt/$max_attempts failed, retrying..."
    sleep 3
    ((attempt++))
done

if [ $attempt -gt $max_attempts ]; then
    print_error "STANDBY health check failed after $max_attempts attempts"
    print_info "Check logs: ssh root@${STANDBY_IP} 'journalctl -u cloudigan-api -n 50'"
    exit 1
fi
echo ""

# Step 11: Summary
print_success "=== Blue-Green Setup Complete ==="
echo ""
print_info "Container Details:"
echo "  LIVE (Blue):    CT${LIVE_CTID} @ ${LIVE_IP} (${LIVE_NAME})"
echo "  STANDBY (Green): CT${STANDBY_CTID} @ ${STANDBY_IP} (${STANDBY_NAME})"
echo ""
print_info "Next Steps:"
echo "  1. Configure HAProxy backends for blue-green routing"
echo "  2. Add SendGrid integration to STANDBY"
echo "  3. Test STANDBY thoroughly"
echo "  4. Switch HAProxy traffic to STANDBY"
echo ""
print_info "Useful Commands:"
echo "  SSH to LIVE:    ssh root@${LIVE_IP}"
echo "  SSH to STANDBY: ssh root@${STANDBY_IP}"
echo "  Health check:   curl http://${STANDBY_IP}:3000/health"
echo "  View logs:      ssh root@${STANDBY_IP} 'journalctl -u cloudigan-api -f'"
echo ""
print_info "Documentation: /Users/cory/Projects/homelab-nexus/documentation/CLOUDIGAN-API-BLUE-GREEN-SETUP.md"
echo ""
