#!/bin/bash
#
# AdGuard Home DNS Rewrite Management Script
# Updates DNS rewrites via AdGuard Home API
#
# Prerequisites:
# - AdGuard Home running and accessible
# - Admin credentials for API authentication
#
# Usage:
#   ./update-adguard-dns.sh add <hostname> <ip>
#   ./update-adguard-dns.sh remove <hostname> <ip>
#   ./update-adguard-dns.sh update <old-hostname> <new-hostname> <ip>
#   ./update-adguard-dns.sh list
#

set -euo pipefail

# Configuration
ADGUARD_HOST="10.92.3.11"
ADGUARD_PORT="3000"
ADGUARD_URL="http://${ADGUARD_HOST}:${ADGUARD_PORT}"
DNS_DOMAIN="cloudigan.net"

# AdGuard credentials (set via environment or prompt)
ADGUARD_USER="${ADGUARD_USER:-admin}"
ADGUARD_PASS="${ADGUARD_PASS:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

check_adguard_connection() {
    log_info "Testing connection to AdGuard Home (${ADGUARD_URL})..."
    
    if curl -s -f "${ADGUARD_URL}/control/status" &>/dev/null; then
        log_success "AdGuard Home is reachable"
        return 0
    else
        log_error "Cannot connect to AdGuard Home at ${ADGUARD_URL}"
        log_error "Please ensure AdGuard Home is running and accessible"
        return 1
    fi
}

get_credentials() {
    if [[ -z "${ADGUARD_PASS}" ]]; then
        log_info "AdGuard credentials required"
        read -p "Username [${ADGUARD_USER}]: " input_user
        ADGUARD_USER="${input_user:-$ADGUARD_USER}"
        
        read -sp "Password: " ADGUARD_PASS
        echo
    fi
}

add_dns_rewrite() {
    local hostname="$1"
    local ip="$2"
    local fqdn="${hostname}.${DNS_DOMAIN}"
    
    log_info "Adding DNS rewrite: ${fqdn} → ${ip}"
    
    get_credentials
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
        -X POST "${ADGUARD_URL}/control/rewrite/add" \
        -H "Content-Type: application/json" \
        -d "{\"domain\": \"${fqdn}\", \"answer\": \"${ip}\"}")
    
    local http_code
    http_code=$(echo "${response}" | tail -n1)
    local body
    body=$(echo "${response}" | head -n-1)
    
    if [[ "${http_code}" == "200" ]]; then
        log_success "DNS rewrite added: ${fqdn} → ${ip}"
        return 0
    elif echo "${body}" | grep -q "already exists"; then
        log_warning "DNS rewrite already exists: ${fqdn} → ${ip}"
        return 0
    else
        log_error "Failed to add DNS rewrite (HTTP ${http_code})"
        echo "${body}"
        return 1
    fi
}

remove_dns_rewrite() {
    local hostname="$1"
    local ip="$2"
    local fqdn="${hostname}.${DNS_DOMAIN}"
    
    log_info "Removing DNS rewrite: ${fqdn} → ${ip}"
    
    get_credentials
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
        -X POST "${ADGUARD_URL}/control/rewrite/delete" \
        -H "Content-Type: application/json" \
        -d "{\"domain\": \"${fqdn}\", \"answer\": \"${ip}\"}")
    
    local http_code
    http_code=$(echo "${response}" | tail -n1)
    
    if [[ "${http_code}" == "200" ]]; then
        log_success "DNS rewrite removed: ${fqdn} → ${ip}"
        return 0
    else
        log_warning "DNS rewrite may not exist or already removed: ${fqdn}"
        return 0
    fi
}

update_dns_rewrite() {
    local old_hostname="$1"
    local new_hostname="$2"
    local ip="$3"
    
    log_info "Updating DNS rewrite: ${old_hostname} → ${new_hostname} (${ip})"
    
    # Remove old rewrite
    remove_dns_rewrite "${old_hostname}" "${ip}"
    
    # Add new rewrite
    add_dns_rewrite "${new_hostname}" "${ip}"
    
    log_success "DNS rewrite updated successfully"
}

list_dns_rewrites() {
    log_info "Listing all DNS rewrites..."
    
    get_credentials
    
    local response
    response=$(curl -s \
        -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
        "${ADGUARD_URL}/control/rewrite/list")
    
    if command -v jq &>/dev/null; then
        echo "${response}" | jq -r '.[] | "\(.domain) → \(.answer)"'
    else
        echo "${response}"
        log_warning "Install 'jq' for better formatting"
    fi
}

verify_dns_rewrite() {
    local hostname="$1"
    local fqdn="${hostname}.${DNS_DOMAIN}"
    
    log_info "Verifying DNS rewrite: ${fqdn}"
    
    get_credentials
    
    local response
    response=$(curl -s \
        -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
        "${ADGUARD_URL}/control/rewrite/list")
    
    if echo "${response}" | grep -q "\"${fqdn}\""; then
        log_success "DNS rewrite exists for: ${fqdn}"
        if command -v jq &>/dev/null; then
            echo "${response}" | jq -r ".[] | select(.domain == \"${fqdn}\") | \"${fqdn} → \(.answer)\""
        fi
        return 0
    else
        log_warning "No DNS rewrite found for: ${fqdn}"
        return 1
    fi
}

show_usage() {
    cat << EOF
Usage: $0 <command> [arguments]

Commands:
  add <hostname> <ip>                    Add DNS rewrite
  remove <hostname> <ip>                 Remove DNS rewrite
  update <old-hostname> <new-hostname> <ip>  Update DNS rewrite (remove old, add new)
  verify <hostname>                      Verify DNS rewrite exists
  list                                   List all DNS rewrites
  test                                   Test connection to AdGuard Home

Examples:
  $0 add bni-toolkit-dev 10.92.3.13
  $0 remove sandbox-01 10.92.3.13
  $0 update sandbox-01 bni-toolkit-dev 10.92.3.13
  $0 verify bni-toolkit-dev
  $0 list
  $0 test

Configuration:
  AdGuard URL: ${ADGUARD_URL}
  DNS Domain:  ${DNS_DOMAIN}

Environment Variables:
  ADGUARD_USER - AdGuard admin username (default: admin)
  ADGUARD_PASS - AdGuard admin password (will prompt if not set)

Prerequisites:
  - AdGuard Home running and accessible
  - Admin credentials for API authentication

EOF
}

# Main script
main() {
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "${command}" in
        add)
            if [[ $# -ne 2 ]]; then
                log_error "Usage: $0 add <hostname> <ip>"
                exit 1
            fi
            check_adguard_connection || exit 1
            add_dns_rewrite "$1" "$2"
            ;;
        remove)
            if [[ $# -ne 2 ]]; then
                log_error "Usage: $0 remove <hostname> <ip>"
                exit 1
            fi
            check_adguard_connection || exit 1
            remove_dns_rewrite "$1" "$2"
            ;;
        update)
            if [[ $# -ne 3 ]]; then
                log_error "Usage: $0 update <old-hostname> <new-hostname> <ip>"
                exit 1
            fi
            check_adguard_connection || exit 1
            update_dns_rewrite "$1" "$2" "$3"
            ;;
        verify)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 verify <hostname>"
                exit 1
            fi
            check_adguard_connection || exit 1
            verify_dns_rewrite "$1"
            ;;
        list)
            check_adguard_connection || exit 1
            list_dns_rewrites
            ;;
        test)
            check_adguard_connection
            ;;
        *)
            log_error "Unknown command: ${command}"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
