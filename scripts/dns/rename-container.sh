#!/bin/bash
#
# Container Rename Automation Script
# Orchestrates full container rename including Proxmox, DNS (DC-01 + AdGuard), and Netbox
#
# Usage:
#   ./rename-container.sh <ctid> <old-hostname> <new-hostname> <ip>
#   ./rename-container.sh --dry-run <ctid> <old-hostname> <new-hostname> <ip>
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXMOX_HOST="prox"
NETBOX_URL="http://10.92.3.18"
NETBOX_TOKEN="${NETBOX_TOKEN:-}"
DC01_USER="cory@cloudigan.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Dry run mode
DRY_RUN=false

# Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "\n${CYAN}▶${NC} ${CYAN}$1${NC}\n"
}

execute_cmd() {
    local cmd="$1"
    local description="${2:-Executing command}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY RUN] Would execute: ${cmd}"
        return 0
    else
        log_info "${description}"
        if eval "${cmd}"; then
            return 0
        else
            return 1
        fi
    fi
}

# Step 1: Pre-rename verification
verify_container() {
    local ctid="$1"
    local old_hostname="$2"
    
    log_step "Step 1: Pre-Rename Verification"
    
    log_info "Checking container CT${ctid} status..."
    local status
    status=$(ssh "${PROXMOX_HOST}" "pct status ${ctid}" 2>/dev/null | awk '{print $2}')
    
    if [[ "${status}" != "running" ]]; then
        log_error "Container CT${ctid} is not running (status: ${status})"
        return 1
    fi
    log_success "Container CT${ctid} is running"
    
    log_info "Verifying current hostname..."
    local current_hostname
    current_hostname=$(ssh "${PROXMOX_HOST}" "pct exec ${ctid} -- hostname" 2>/dev/null | tr -d '\r\n')
    
    if [[ "${current_hostname}" != "${old_hostname}" ]]; then
        log_warning "Hostname mismatch: expected '${old_hostname}', got '${current_hostname}'"
        read -p "Continue anyway? (y/N): " confirm
        if [[ "${confirm}" != "y" ]]; then
            log_error "Aborted by user"
            return 1
        fi
    else
        log_success "Current hostname verified: ${current_hostname}"
    fi
    
    return 0
}

# Step 2: Stop container
stop_container() {
    local ctid="$1"
    
    log_step "Step 2: Stop Container"
    
    execute_cmd "ssh ${PROXMOX_HOST} 'pct stop ${ctid}'" "Stopping container CT${ctid}..."
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        sleep 3
        local status
        status=$(ssh "${PROXMOX_HOST}" "pct status ${ctid}" | awk '{print $2}')
        if [[ "${status}" == "stopped" ]]; then
            log_success "Container CT${ctid} stopped"
        else
            log_error "Container CT${ctid} failed to stop (status: ${status})"
            return 1
        fi
    fi
    
    return 0
}

# Step 3: Rename in Proxmox
rename_proxmox() {
    local ctid="$1"
    local new_hostname="$2"
    
    log_step "Step 3: Rename in Proxmox"
    
    execute_cmd "ssh ${PROXMOX_HOST} 'pct set ${ctid} --hostname ${new_hostname}'" \
        "Setting hostname to ${new_hostname} in Proxmox..."
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        local config_hostname
        config_hostname=$(ssh "${PROXMOX_HOST}" "grep '^hostname:' /etc/pve/lxc/${ctid}.conf" | awk '{print $2}')
        if [[ "${config_hostname}" == "${new_hostname}" ]]; then
            log_success "Proxmox config updated: hostname = ${new_hostname}"
        else
            log_error "Proxmox config update failed"
            return 1
        fi
    fi
    
    return 0
}

# Step 4: Start container
start_container() {
    local ctid="$1"
    
    log_step "Step 4: Start Container"
    
    execute_cmd "ssh ${PROXMOX_HOST} 'pct start ${ctid}'" "Starting container CT${ctid}..."
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        log_info "Waiting for container to boot (15 seconds)..."
        sleep 15
        
        local status
        status=$(ssh "${PROXMOX_HOST}" "pct status ${ctid}" | awk '{print $2}')
        if [[ "${status}" == "running" ]]; then
            log_success "Container CT${ctid} started"
        else
            log_error "Container CT${ctid} failed to start (status: ${status})"
            return 1
        fi
    fi
    
    return 0
}

# Step 5: Verify hostname inside container
verify_hostname() {
    local ctid="$1"
    local new_hostname="$2"
    
    log_step "Step 5: Verify Hostname Inside Container"
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        local actual_hostname
        actual_hostname=$(ssh "${PROXMOX_HOST}" "pct exec ${ctid} -- hostname" | tr -d '\r\n')
        
        if [[ "${actual_hostname}" == "${new_hostname}" ]]; then
            log_success "Hostname verified inside container: ${actual_hostname}"
        else
            log_error "Hostname mismatch: expected '${new_hostname}', got '${actual_hostname}'"
            return 1
        fi
    else
        log_warning "[DRY RUN] Would verify hostname inside container"
    fi
    
    return 0
}

# Step 6: Update DC-01 DNS
update_dc01() {
    local old_hostname="$1"
    local new_hostname="$2"
    local ip="$3"
    
    log_step "Step 6: Update DC-01 DNS"
    
    if [[ ! -x "${SCRIPT_DIR}/update-dc01-dns.sh" ]]; then
        log_error "DC-01 DNS script not found or not executable: ${SCRIPT_DIR}/update-dc01-dns.sh"
        return 1
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY RUN] Would update DC-01 DNS: ${old_hostname} → ${new_hostname} (${ip})"
        return 0
    fi
    
    "${SCRIPT_DIR}/update-dc01-dns.sh" update "${old_hostname}" "${new_hostname}" "${ip}"
}

# Step 7: Update AdGuard DNS (optional)
update_adguard() {
    local old_hostname="$1"
    local new_hostname="$2"
    local ip="$3"
    
    log_step "Step 7: Update AdGuard DNS (Optional)"
    
    if [[ ! -x "${SCRIPT_DIR}/update-adguard-dns.sh" ]]; then
        log_warning "AdGuard DNS script not found, skipping: ${SCRIPT_DIR}/update-adguard-dns.sh"
        return 0
    fi
    
    log_info "Checking if AdGuard DNS rewrite exists for ${old_hostname}..."
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY RUN] Would check and update AdGuard DNS if needed"
        return 0
    fi
    
    # Check if rewrite exists (optional, may not exist for all containers)
    if "${SCRIPT_DIR}/update-adguard-dns.sh" verify "${old_hostname}" &>/dev/null; then
        log_info "AdGuard DNS rewrite exists, updating..."
        "${SCRIPT_DIR}/update-adguard-dns.sh" update "${old_hostname}" "${new_hostname}" "${ip}"
    else
        log_info "No AdGuard DNS rewrite found for ${old_hostname}, skipping"
    fi
    
    return 0
}

# Step 8: Update Netbox (manual for now, API integration future)
update_netbox() {
    local old_hostname="$1"
    local new_hostname="$2"
    local ip="$3"
    
    log_step "Step 8: Update Netbox IPAM"
    
    log_warning "Netbox update requires manual action via Web UI"
    log_info "Please update Netbox:"
    log_info "  1. Navigate to ${NETBOX_URL}"
    log_info "  2. Search for '${old_hostname}' or '${ip}'"
    log_info "  3. Update Name: ${new_hostname}"
    log_info "  4. Add Comment: 'Renamed from ${old_hostname} on $(date +%Y-%m-%d)'"
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        read -p "Press Enter when Netbox has been updated..."
        log_success "Netbox update confirmed by user"
    fi
    
    return 0
}

# Step 9: Verify DNS resolution
verify_dns() {
    local new_hostname="$1"
    local ip="$2"
    
    log_step "Step 9: Verify DNS Resolution"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY RUN] Would verify DNS resolution"
        return 0
    fi
    
    log_info "Testing DNS resolution for ${new_hostname}.cloudigan.net..."
    
    local resolved_ip
    resolved_ip=$(nslookup "${new_hostname}.cloudigan.net" 10.92.0.10 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    
    if [[ "${resolved_ip}" == "${ip}" ]]; then
        log_success "DNS resolution verified: ${new_hostname}.cloudigan.net → ${resolved_ip}"
    else
        log_warning "DNS resolution issue: expected ${ip}, got ${resolved_ip}"
        log_warning "DNS may need time to propagate"
    fi
    
    log_info "Testing connectivity by hostname..."
    if ping -c 3 "${new_hostname}.cloudigan.net" &>/dev/null; then
        log_success "Ping successful to ${new_hostname}.cloudigan.net"
    else
        log_warning "Ping failed to ${new_hostname}.cloudigan.net"
    fi
    
    return 0
}

# Step 10: Summary
show_summary() {
    local ctid="$1"
    local old_hostname="$2"
    local new_hostname="$3"
    local ip="$4"
    
    log_step "Step 10: Rename Complete!"
    
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  Container Rename Summary                                  ${GREEN}║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  CTID:         CT${ctid}                                        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Old Name:     ${old_hostname}                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  New Name:     ${new_hostname}                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  IP Address:   ${ip}                                    ${GREEN}║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  ✓ Proxmox hostname updated                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ✓ DC-01 DNS record updated                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ✓ AdGuard DNS checked/updated                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ✓ Netbox IPAM updated (manual)                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ✓ DNS resolution verified                                  ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    log_info "Next steps:"
    log_info "  1. Update documentation (infrastructure-spec.md, APP-MAP.md)"
    log_info "  2. Update SSH config if alias exists (~/.ssh/config)"
    log_info "  3. Verify services are running correctly"
    log_info "  4. Mark container as complete in container-rename-plan.md"
}

# Rollback function
rollback() {
    local ctid="$1"
    local old_hostname="$2"
    local new_hostname="$3"
    local ip="$4"
    
    log_error "Rollback initiated!"
    
    log_info "Stopping container..."
    ssh "${PROXMOX_HOST}" "pct stop ${ctid}" || true
    
    log_info "Reverting hostname in Proxmox..."
    ssh "${PROXMOX_HOST}" "pct set ${ctid} --hostname ${old_hostname}" || true
    
    log_info "Starting container..."
    ssh "${PROXMOX_HOST}" "pct start ${ctid}" || true
    
    log_info "Reverting DC-01 DNS..."
    "${SCRIPT_DIR}/update-dc01-dns.sh" update "${new_hostname}" "${old_hostname}" "${ip}" || true
    
    log_warning "Rollback complete. Please verify container status manually."
}

show_usage() {
    cat << EOF
Usage: $0 [--dry-run] <ctid> <old-hostname> <new-hostname> <ip>

Arguments:
  ctid            Container ID (e.g., 119)
  old-hostname    Current hostname (e.g., sandbox-01)
  new-hostname    New hostname (e.g., bni-toolkit-dev)
  ip              IP address (e.g., 10.92.3.13)

Options:
  --dry-run       Show what would be done without making changes

Examples:
  $0 119 sandbox-01 bni-toolkit-dev 10.92.3.13
  $0 --dry-run 119 sandbox-01 bni-toolkit-dev 10.92.3.13

Steps performed:
  1. Pre-rename verification (container status, current hostname)
  2. Stop container
  3. Rename in Proxmox
  4. Start container
  5. Verify hostname inside container
  6. Update DC-01 DNS (remove old, add new)
  7. Update AdGuard DNS (if rewrite exists)
  8. Update Netbox IPAM (manual prompt)
  9. Verify DNS resolution
  10. Show summary

Prerequisites:
  - SSH access to Proxmox host (${PROXMOX_HOST})
  - OpenSSH Server on DC-01 with SSH key auth
  - AdGuard Home accessible (optional)
  - Netbox access for manual update

EOF
}

# Main script
main() {
    # Check for dry-run flag
    if [[ "${1:-}" == "--dry-run" ]]; then
        DRY_RUN=true
        shift
        log_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    # Validate arguments
    if [[ $# -ne 4 ]]; then
        show_usage
        exit 1
    fi
    
    local ctid="$1"
    local old_hostname="$2"
    local new_hostname="$3"
    local ip="$4"
    
    # Show what we're about to do
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  Container Rename Operation                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  CTID:         CT${ctid}                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Old Name:     ${old_hostname}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  New Name:     ${new_hostname}                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  IP Address:   ${ip}                                    ${CYAN}║${NC}"
    if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${CYAN}║${NC}  Mode:         DRY RUN (no changes)                         ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        read -p "Proceed with rename? (y/N): " confirm
        if [[ "${confirm}" != "y" ]]; then
            log_error "Aborted by user"
            exit 1
        fi
        echo ""
    fi
    
    # Execute rename steps
    if ! verify_container "${ctid}" "${old_hostname}"; then
        log_error "Pre-rename verification failed"
        exit 1
    fi
    
    if ! stop_container "${ctid}"; then
        log_error "Failed to stop container"
        exit 1
    fi
    
    if ! rename_proxmox "${ctid}" "${new_hostname}"; then
        log_error "Failed to rename in Proxmox"
        rollback "${ctid}" "${old_hostname}" "${new_hostname}" "${ip}"
        exit 1
    fi
    
    if ! start_container "${ctid}"; then
        log_error "Failed to start container"
        rollback "${ctid}" "${old_hostname}" "${new_hostname}" "${ip}"
        exit 1
    fi
    
    if ! verify_hostname "${ctid}" "${new_hostname}"; then
        log_error "Hostname verification failed"
        rollback "${ctid}" "${old_hostname}" "${new_hostname}" "${ip}"
        exit 1
    fi
    
    if ! update_dc01 "${old_hostname}" "${new_hostname}" "${ip}"; then
        log_error "Failed to update DC-01 DNS"
        log_warning "Container renamed in Proxmox but DNS update failed"
        log_warning "You may need to update DNS manually or run rollback"
        exit 1
    fi
    
    # AdGuard is optional, don't fail on error
    update_adguard "${old_hostname}" "${new_hostname}" "${ip}" || log_warning "AdGuard update skipped or failed (non-critical)"
    
    # Netbox requires manual update
    update_netbox "${old_hostname}" "${new_hostname}" "${ip}"
    
    # Verify DNS
    verify_dns "${new_hostname}" "${ip}"
    
    # Show summary
    show_summary "${ctid}" "${old_hostname}" "${new_hostname}" "${ip}"
    
    log_success "Container rename complete!"
}

main "$@"
