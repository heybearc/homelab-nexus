#!/bin/bash
#
# Complete System Verification Script
# Verifies container configuration across all systems: Proxmox, DC-01 DNS, NPM, AdGuard, Netbox
#
# Usage:
#   ./verify-all-systems.sh <ctid> <hostname> <ip>
#   ./verify-all-systems.sh 119 bni-toolkit-dev 10.92.3.12
#

set -euo pipefail

# Configuration
PROXMOX_HOST="prox"
DC01_HOST="10.92.0.10"
DC01_USER="cory@cloudigan.com"
DNS_ZONE="cloudigan.net"
NPM_HOST="10.92.3.3"
NPM_PORT="81"
ADGUARD_HOST="10.92.3.11"
ADGUARD_PORT="3000"
NETBOX_HOST="10.92.3.18"
NETBOX_API="http://${NETBOX_HOST}/api"

# Credentials (set via environment or will prompt)
ADGUARD_USER="${ADGUARD_USER:-admin}"
ADGUARD_PASS="${ADGUARD_PASS:-}"
NETBOX_TOKEN="${NETBOX_TOKEN:-}"
NPM_EMAIL="${NPM_EMAIL:-}"
NPM_PASS="${NPM_PASS:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Results tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNING_CHECKS++))
}

log_error() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
}

log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

check_proxmox() {
    local ctid="$1"
    local expected_hostname="$2"
    local expected_ip="$3"
    
    log_section "1. PROXMOX CONFIGURATION"
    
    ((TOTAL_CHECKS++))
    log_info "Checking container CT${ctid} exists..."
    if ssh "${PROXMOX_HOST}" "pct status ${ctid}" &>/dev/null; then
        log_success "Container CT${ctid} exists"
    else
        log_error "Container CT${ctid} not found"
        return 1
    fi
    
    ((TOTAL_CHECKS++))
    log_info "Checking container status..."
    local status
    status=$(ssh "${PROXMOX_HOST}" "pct status ${ctid}" | awk '{print $2}')
    if [[ "${status}" == "running" ]]; then
        log_success "Container is running"
    else
        log_warning "Container is ${status}"
    fi
    
    ((TOTAL_CHECKS++))
    log_info "Checking hostname in config..."
    local actual_hostname
    actual_hostname=$(ssh "${PROXMOX_HOST}" "pct config ${ctid} | grep '^hostname:' | awk '{print \$2}'")
    if [[ "${actual_hostname}" == "${expected_hostname}" ]]; then
        log_success "Hostname in config: ${actual_hostname}"
    else
        log_error "Hostname mismatch: expected '${expected_hostname}', got '${actual_hostname}'"
    fi
    
    ((TOTAL_CHECKS++))
    log_info "Checking IP address..."
    local actual_ip
    actual_ip=$(ssh "${PROXMOX_HOST}" "pct config ${ctid} | grep 'ip=' | grep -oP 'ip=\K[0-9.]+'" || echo "")
    if [[ "${actual_ip}" == "${expected_ip}" ]]; then
        log_success "IP address: ${actual_ip}"
    else
        log_error "IP mismatch: expected '${expected_ip}', got '${actual_ip}'"
    fi
    
    ((TOTAL_CHECKS++))
    log_info "Checking hostname inside container..."
    if [[ "${status}" == "running" ]]; then
        local inside_hostname
        inside_hostname=$(ssh "${PROXMOX_HOST}" "pct exec ${ctid} -- hostname" 2>/dev/null | tr -d '\r\n')
        if [[ "${inside_hostname}" == "${expected_hostname}" ]]; then
            log_success "Hostname inside container: ${inside_hostname}"
        else
            log_error "Hostname inside mismatch: expected '${expected_hostname}', got '${inside_hostname}'"
        fi
    else
        log_warning "Skipping inside check (container not running)"
    fi
}

check_dc01_dns() {
    local hostname="$1"
    local expected_ip="$2"
    
    log_section "2. DC-01 DNS RECORDS"
    
    ((TOTAL_CHECKS++))
    log_info "Checking DNS record for ${hostname}.${DNS_ZONE}..."
    local dns_result
    dns_result=$(nslookup "${hostname}.${DNS_ZONE}" "${DC01_HOST}" 2>&1)
    
    if echo "${dns_result}" | grep -q "NXDOMAIN"; then
        log_error "DNS record not found: ${hostname}.${DNS_ZONE}"
    elif echo "${dns_result}" | grep -q "${expected_ip}"; then
        log_success "DNS record exists: ${hostname}.${DNS_ZONE} → ${expected_ip}"
    else
        local actual_ip
        actual_ip=$(echo "${dns_result}" | grep "Address:" | tail -1 | awk '{print $2}')
        log_error "DNS IP mismatch: expected ${expected_ip}, got ${actual_ip}"
    fi
    
    ((TOTAL_CHECKS++))
    log_info "Testing DNS resolution from Proxmox..."
    if ssh "${PROXMOX_HOST}" "ping -c 1 ${hostname}.${DNS_ZONE}" &>/dev/null; then
        log_success "DNS resolution working from Proxmox"
    else
        log_error "DNS resolution failed from Proxmox"
    fi
}

check_npm() {
    local hostname="$1"
    local ip="$2"
    
    log_section "3. NGINX PROXY MANAGER (NPM)"
    
    ((TOTAL_CHECKS++))
    log_info "Checking NPM accessibility..."
    if curl -s -f "http://${NPM_HOST}:${NPM_PORT}" &>/dev/null; then
        log_success "NPM is accessible at http://${NPM_HOST}:${NPM_PORT}"
    else
        log_error "Cannot access NPM at http://${NPM_HOST}:${NPM_PORT}"
        return 1
    fi
    
    log_warning "NPM API check requires credentials (NPM_EMAIL and NPM_PASS)"
    log_info "Manual verification needed:"
    log_info "  1. Login to http://${NPM_HOST}:${NPM_PORT}"
    log_info "  2. Go to 'Proxy Hosts'"
    log_info "  3. Search for domains pointing to ${ip}"
    log_info "  4. Verify configurations are correct"
}

check_adguard() {
    local hostname="$1"
    
    log_section "4. ADGUARD HOME DNS REWRITES"
    
    ((TOTAL_CHECKS++))
    log_info "Checking AdGuard accessibility..."
    if curl -s -f "http://${ADGUARD_HOST}:${ADGUARD_PORT}/control/status" &>/dev/null; then
        log_success "AdGuard is accessible"
    else
        log_error "Cannot access AdGuard at http://${ADGUARD_HOST}:${ADGUARD_PORT}"
        return 1
    fi
    
    if [[ -z "${ADGUARD_PASS}" ]]; then
        log_warning "ADGUARD_PASS not set - skipping DNS rewrite check"
        log_info "Set ADGUARD_USER and ADGUARD_PASS environment variables to enable"
        return 0
    fi
    
    ((TOTAL_CHECKS++))
    log_info "Checking DNS rewrites for ${hostname}..."
    local rewrites
    rewrites=$(curl -s -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
        "http://${ADGUARD_HOST}:${ADGUARD_PORT}/control/rewrite/list" 2>/dev/null)
    
    if echo "${rewrites}" | grep -q "\"${hostname}.${DNS_ZONE}\""; then
        log_warning "DNS rewrite exists for ${hostname}.${DNS_ZONE}"
        log_info "This may conflict with DC-01 DNS - consider removing"
    else
        log_success "No DNS rewrite for ${hostname}.${DNS_ZONE} (using DC-01 DNS)"
    fi
}

check_netbox() {
    local hostname="$1"
    local ip="$2"
    local ctid="$3"
    
    log_section "5. NETBOX IPAM"
    
    ((TOTAL_CHECKS++))
    log_info "Checking Netbox accessibility..."
    if curl -s -f "${NETBOX_API}/" &>/dev/null; then
        log_success "Netbox API is accessible"
    else
        log_error "Cannot access Netbox API at ${NETBOX_API}"
        return 1
    fi
    
    if [[ -z "${NETBOX_TOKEN}" ]]; then
        log_warning "NETBOX_TOKEN not set - skipping VM lookup"
        log_info "Set NETBOX_TOKEN environment variable to enable"
        log_info "Get token from: http://${NETBOX_HOST}/user/api-tokens/"
        return 0
    fi
    
    ((TOTAL_CHECKS++))
    log_info "Searching for VM by name: ${hostname}..."
    local vm_search
    vm_search=$(curl -s -H "Authorization: Token ${NETBOX_TOKEN}" \
        "${NETBOX_API}/virtualization/virtual-machines/?name=${hostname}" 2>/dev/null)
    
    if echo "${vm_search}" | grep -q "\"count\":0"; then
        log_error "VM not found in Netbox with name: ${hostname}"
    else
        log_success "VM found in Netbox: ${hostname}"
        
        # Check IP address
        ((TOTAL_CHECKS++))
        log_info "Verifying IP address in Netbox..."
        if echo "${vm_search}" | grep -q "${ip}"; then
            log_success "IP address matches: ${ip}"
        else
            log_warning "IP address may not match in Netbox"
        fi
    fi
    
    ((TOTAL_CHECKS++))
    log_info "Searching for IP address: ${ip}..."
    local ip_search
    ip_search=$(curl -s -H "Authorization: Token ${NETBOX_TOKEN}" \
        "${NETBOX_API}/ipam/ip-addresses/?address=${ip}" 2>/dev/null)
    
    if echo "${ip_search}" | grep -q "\"count\":0"; then
        log_warning "IP address not found in Netbox IPAM: ${ip}"
    else
        log_success "IP address found in Netbox IPAM: ${ip}"
    fi
}

show_summary() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  VERIFICATION SUMMARY${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Total Checks:   ${TOTAL_CHECKS}"
    echo -e "${GREEN}Passed:         ${PASSED_CHECKS}${NC}"
    echo -e "${YELLOW}Warnings:       ${WARNING_CHECKS}${NC}"
    echo -e "${RED}Failed:         ${FAILED_CHECKS}${NC}"
    echo ""
    
    if [[ ${FAILED_CHECKS} -eq 0 ]] && [[ ${WARNING_CHECKS} -eq 0 ]]; then
        echo -e "${GREEN}✓ All checks passed!${NC}"
        return 0
    elif [[ ${FAILED_CHECKS} -eq 0 ]]; then
        echo -e "${YELLOW}⚠ All checks passed with warnings${NC}"
        return 0
    else
        echo -e "${RED}✗ Some checks failed - review output above${NC}"
        return 1
    fi
}

show_usage() {
    cat << EOF
Usage: $0 <ctid> <hostname> <ip>

Verifies container configuration across all systems:
  - Proxmox (container config and status)
  - DC-01 DNS (A records)
  - NPM (proxy hosts) - manual verification
  - AdGuard (DNS rewrites) - requires ADGUARD_PASS
  - Netbox (VM and IP records) - requires NETBOX_TOKEN

Arguments:
  ctid        Container ID (e.g., 119)
  hostname    Container hostname (e.g., bni-toolkit-dev)
  ip          IP address (e.g., 10.92.3.12)

Environment Variables:
  ADGUARD_USER    AdGuard username (default: admin)
  ADGUARD_PASS    AdGuard password (required for rewrite checks)
  NETBOX_TOKEN    Netbox API token (required for VM/IP lookups)
  NPM_EMAIL       NPM email (for future API integration)
  NPM_PASS        NPM password (for future API integration)

Examples:
  $0 119 bni-toolkit-dev 10.92.3.12
  
  # With credentials
  ADGUARD_PASS="password" NETBOX_TOKEN="token" $0 119 bni-toolkit-dev 10.92.3.12

Get API Tokens:
  Netbox: http://10.92.3.18/user/api-tokens/
  AdGuard: Use web UI password
  NPM: http://10.92.3.3:81 (future API integration)

EOF
}

main() {
    if [[ $# -ne 3 ]]; then
        show_usage
        exit 1
    fi
    
    local ctid="$1"
    local hostname="$2"
    local ip="$3"
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  Complete System Verification                              ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  CTID:     CT${ctid}                                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Hostname: ${hostname}                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  IP:       ${ip}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    
    check_proxmox "${ctid}" "${hostname}" "${ip}"
    check_dc01_dns "${hostname}" "${ip}"
    check_npm "${hostname}" "${ip}"
    check_adguard "${hostname}"
    check_netbox "${hostname}" "${ip}" "${ctid}"
    
    show_summary
}

main "$@"
