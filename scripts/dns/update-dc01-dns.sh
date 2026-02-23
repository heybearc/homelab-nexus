#!/bin/bash
#
# DC-01 DNS Record Management Script
# Updates Windows Server Active Directory DNS via SSH + PowerShell
#
# Prerequisites:
# - OpenSSH Server installed on DC-01 (Windows Server)
# - SSH key-based authentication configured
# - PowerShell DNS cmdlets available (default on Windows Server)
#
# Usage:
#   ./update-dc01-dns.sh add <hostname> <ip>
#   ./update-dc01-dns.sh remove <hostname>
#   ./update-dc01-dns.sh update <old-hostname> <new-hostname> <ip>
#   ./update-dc01-dns.sh verify <hostname>
#

set -euo pipefail

# Configuration
DC01_HOST="10.92.0.10"
DC01_USER="Administrator"
DNS_ZONE="cloudigan.net"
SSH_KEY="${HOME}/.ssh/id_rsa"

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

check_ssh_connection() {
    log_info "Testing SSH connection to DC-01 (${DC01_HOST})..."
    
    if ssh -i "${SSH_KEY}" -o ConnectTimeout=5 -o BatchMode=yes "${DC01_USER}@${DC01_HOST}" "echo 'SSH connection successful'" &>/dev/null; then
        log_success "SSH connection to DC-01 successful"
        return 0
    else
        log_error "Cannot connect to DC-01 via SSH"
        log_error "Please ensure:"
        log_error "  1. OpenSSH Server is installed on DC-01"
        log_error "  2. SSH key is configured: ${SSH_KEY}"
        log_error "  3. DC-01 is reachable at ${DC01_HOST}"
        return 1
    fi
}

add_dns_record() {
    local hostname="$1"
    local ip="$2"
    
    log_info "Adding DNS A record: ${hostname}.${DNS_ZONE} → ${ip}"
    
    # PowerShell command to add DNS record
    local ps_cmd="Add-DnsServerResourceRecord -ZoneName '${DNS_ZONE}' -Name '${hostname}' -A -IPv4Address '${ip}' -ErrorAction Stop"
    
    if ssh -i "${SSH_KEY}" "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command \"${ps_cmd}\"" 2>&1 | grep -q "successfully\|completed"; then
        log_success "DNS record added: ${hostname}.${DNS_ZONE} → ${ip}"
        return 0
    else
        # Check if record already exists
        if verify_dns_record "${hostname}" "${ip}"; then
            log_warning "DNS record already exists: ${hostname}.${DNS_ZONE} → ${ip}"
            return 0
        else
            log_error "Failed to add DNS record"
            return 1
        fi
    fi
}

remove_dns_record() {
    local hostname="$1"
    
    log_info "Removing DNS A record: ${hostname}.${DNS_ZONE}"
    
    # PowerShell command to remove DNS record
    local ps_cmd="Remove-DnsServerResourceRecord -ZoneName '${DNS_ZONE}' -Name '${hostname}' -RRType A -Force -ErrorAction Stop"
    
    if ssh -i "${SSH_KEY}" "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command \"${ps_cmd}\"" 2>&1; then
        log_success "DNS record removed: ${hostname}.${DNS_ZONE}"
        return 0
    else
        log_warning "DNS record may not exist or already removed: ${hostname}.${DNS_ZONE}"
        return 0
    fi
}

verify_dns_record() {
    local hostname="$1"
    local expected_ip="${2:-}"
    
    log_info "Verifying DNS record: ${hostname}.${DNS_ZONE}"
    
    # PowerShell command to get DNS record
    local ps_cmd="Get-DnsServerResourceRecord -ZoneName '${DNS_ZONE}' -Name '${hostname}' -RRType A -ErrorAction SilentlyContinue | Select-Object -ExpandProperty RecordData | Select-Object -ExpandProperty IPv4Address"
    
    local actual_ip
    actual_ip=$(ssh -i "${SSH_KEY}" "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command \"${ps_cmd}\"" 2>/dev/null | tr -d '\r\n ')
    
    if [[ -z "${actual_ip}" ]]; then
        log_error "DNS record not found: ${hostname}.${DNS_ZONE}"
        return 1
    fi
    
    if [[ -n "${expected_ip}" ]]; then
        if [[ "${actual_ip}" == "${expected_ip}" ]]; then
            log_success "DNS record verified: ${hostname}.${DNS_ZONE} → ${actual_ip}"
            return 0
        else
            log_error "DNS record mismatch: expected ${expected_ip}, got ${actual_ip}"
            return 1
        fi
    else
        log_success "DNS record exists: ${hostname}.${DNS_ZONE} → ${actual_ip}"
        return 0
    fi
}

update_dns_record() {
    local old_hostname="$1"
    local new_hostname="$2"
    local ip="$3"
    
    log_info "Updating DNS record: ${old_hostname} → ${new_hostname} (${ip})"
    
    # Remove old record
    remove_dns_record "${old_hostname}"
    
    # Add new record
    add_dns_record "${new_hostname}" "${ip}"
    
    # Verify new record
    if verify_dns_record "${new_hostname}" "${ip}"; then
        log_success "DNS record updated successfully"
        return 0
    else
        log_error "DNS record update verification failed"
        return 1
    fi
}

list_dns_records() {
    log_info "Listing all DNS A records in ${DNS_ZONE}..."
    
    # PowerShell command to list all A records
    local ps_cmd="Get-DnsServerResourceRecord -ZoneName '${DNS_ZONE}' -RRType A | Select-Object HostName, @{Name='IPAddress';Expression={\$_.RecordData.IPv4Address}} | Format-Table -AutoSize"
    
    ssh -i "${SSH_KEY}" "${DC01_USER}@${DC01_HOST}" "powershell.exe -Command \"${ps_cmd}\""
}

show_usage() {
    cat << EOF
Usage: $0 <command> [arguments]

Commands:
  add <hostname> <ip>                    Add new DNS A record
  remove <hostname>                      Remove DNS A record
  update <old-hostname> <new-hostname> <ip>  Update DNS record (remove old, add new)
  verify <hostname> [expected-ip]        Verify DNS record exists (optionally check IP)
  list                                   List all DNS A records
  test                                   Test SSH connection to DC-01

Examples:
  $0 add bni-toolkit-dev 10.92.3.13
  $0 remove sandbox-01
  $0 update sandbox-01 bni-toolkit-dev 10.92.3.13
  $0 verify bni-toolkit-dev 10.92.3.13
  $0 list
  $0 test

Configuration:
  DC-01 Host: ${DC01_HOST}
  DC-01 User: ${DC01_USER}
  DNS Zone:   ${DNS_ZONE}
  SSH Key:    ${SSH_KEY}

Prerequisites:
  - OpenSSH Server installed on DC-01
  - SSH key-based authentication configured
  - PowerShell DNS cmdlets available

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
            check_ssh_connection || exit 1
            add_dns_record "$1" "$2"
            ;;
        remove)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 remove <hostname>"
                exit 1
            fi
            check_ssh_connection || exit 1
            remove_dns_record "$1"
            ;;
        update)
            if [[ $# -ne 3 ]]; then
                log_error "Usage: $0 update <old-hostname> <new-hostname> <ip>"
                exit 1
            fi
            check_ssh_connection || exit 1
            update_dns_record "$1" "$2" "$3"
            ;;
        verify)
            if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
                log_error "Usage: $0 verify <hostname> [expected-ip]"
                exit 1
            fi
            check_ssh_connection || exit 1
            verify_dns_record "$1" "${2:-}"
            ;;
        list)
            check_ssh_connection || exit 1
            list_dns_records
            ;;
        test)
            check_ssh_connection
            ;;
        *)
            log_error "Unknown command: ${command}"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
