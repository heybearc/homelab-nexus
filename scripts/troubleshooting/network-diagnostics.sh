#!/bin/bash
# Network Diagnostics Script
# Comprehensive network troubleshooting for homelab infrastructure

# Configuration
DNS_SERVER="10.92.0.10"
GATEWAY="10.92.3.1"
PROXMOX_HOST="10.92.0.5"
TEST_DOMAINS=("google.com" "cloudflare.com" "github.com")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}[OK]${NC} $message"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${YELLOW}[INFO]${NC} $message"
            ;;
    esac
}

# Function to test basic connectivity
test_connectivity() {
    print_status "INFO" "Testing basic network connectivity..."
    
    # Test gateway connectivity
    if ping -c 3 -W 5 $GATEWAY >/dev/null 2>&1; then
        print_status "OK" "Gateway ($GATEWAY) is reachable"
    else
        print_status "FAIL" "Gateway ($GATEWAY) is unreachable"
    fi
    
    # Test Proxmox host connectivity
    if ping -c 3 -W 5 $PROXMOX_HOST >/dev/null 2>&1; then
        print_status "OK" "Proxmox host ($PROXMOX_HOST) is reachable"
    else
        print_status "FAIL" "Proxmox host ($PROXMOX_HOST) is unreachable"
    fi
    
    # Test DNS server connectivity
    if ping -c 3 -W 5 $DNS_SERVER >/dev/null 2>&1; then
        print_status "OK" "DNS server ($DNS_SERVER) is reachable"
    else
        print_status "FAIL" "DNS server ($DNS_SERVER) is unreachable"
    fi
}

# Function to test DNS resolution
test_dns() {
    print_status "INFO" "Testing DNS resolution..."
    
    for domain in "${TEST_DOMAINS[@]}"; do
        if nslookup $domain $DNS_SERVER >/dev/null 2>&1; then
            print_status "OK" "DNS resolution for $domain successful"
        else
            print_status "FAIL" "DNS resolution for $domain failed"
        fi
    done
    
    # Test reverse DNS
    if nslookup $PROXMOX_HOST $DNS_SERVER >/dev/null 2>&1; then
        print_status "OK" "Reverse DNS for Proxmox host successful"
    else
        print_status "WARN" "Reverse DNS for Proxmox host failed"
    fi
}

# Function to test VPN status
test_vpn() {
    print_status "INFO" "Testing VPN connectivity..."
    
    # Check if TUN interface exists
    if ip link show tun0 >/dev/null 2>&1; then
        print_status "OK" "VPN interface (tun0) is present"
        
        # Get VPN IP
        VPN_IP=$(ip addr show tun0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -n "$VPN_IP" ]; then
            print_status "OK" "VPN IP address: $VPN_IP"
        else
            print_status "FAIL" "No IP address assigned to VPN interface"
        fi
        
        # Test VPN connectivity
        if curl -s --max-time 10 ifconfig.me >/dev/null 2>&1; then
            EXTERNAL_IP=$(curl -s --max-time 10 ifconfig.me)
            print_status "OK" "External IP via VPN: $EXTERNAL_IP"
        else
            print_status "FAIL" "Cannot reach external internet via VPN"
        fi
    else
        print_status "WARN" "VPN interface (tun0) not found - VPN may not be configured"
    fi
}

# Function to check routing table
test_routing() {
    print_status "INFO" "Checking routing table..."
    
    # Display current routes
    echo "Current routing table:"
    ip route show
    echo ""
    
    # Check for VPN routes
    if ip route show | grep -q "tun0"; then
        print_status "OK" "VPN routes are present"
    else
        print_status "WARN" "No VPN routes found"
    fi
    
    # Check for local network routes
    if ip route show | grep -q "10.92"; then
        print_status "OK" "Local network routes are present"
    else
        print_status "FAIL" "Local network routes missing"
    fi
}

# Function to check firewall rules
test_firewall() {
    print_status "INFO" "Checking firewall configuration..."
    
    # Check if iptables has rules
    RULE_COUNT=$(iptables -L | wc -l)
    if [ $RULE_COUNT -gt 10 ]; then
        print_status "OK" "Firewall rules are configured ($RULE_COUNT lines)"
    else
        print_status "WARN" "Minimal or no firewall rules detected"
    fi
    
    # Check for common ports
    if iptables -L | grep -q "22"; then
        print_status "OK" "SSH port (22) rules found"
    else
        print_status "WARN" "No SSH port rules found"
    fi
}

# Function to test service connectivity
test_services() {
    print_status "INFO" "Testing service connectivity..."
    
    # Common service ports to test
    declare -A SERVICES=(
        ["SSH"]="22"
        ["HTTP"]="80"
        ["HTTPS"]="443"
        ["Proxmox"]="8006"
        ["AdGuard"]="3000"
    )
    
    for service in "${!SERVICES[@]}"; do
        port=${SERVICES[$service]}
        if netstat -tuln | grep -q ":$port "; then
            print_status "OK" "$service (port $port) is listening"
        else
            print_status "WARN" "$service (port $port) is not listening"
        fi
    done
}

# Function to check NFS mounts
test_nfs() {
    print_status "INFO" "Checking NFS mounts..."
    
    if mount | grep -q "nfs"; then
        print_status "OK" "NFS mounts detected:"
        mount | grep nfs | while read line; do
            echo "  $line"
        done
    else
        print_status "WARN" "No NFS mounts found"
    fi
    
    # Test /mnt/data if it exists
    if [ -d "/mnt/data" ]; then
        if mountpoint -q /mnt/data; then
            print_status "OK" "/mnt/data is properly mounted"
        else
            print_status "FAIL" "/mnt/data exists but is not mounted"
        fi
    else
        print_status "WARN" "/mnt/data directory does not exist"
    fi
}

# Function to generate summary report
generate_summary() {
    print_status "INFO" "Network Diagnostics Summary"
    echo "=================================="
    echo "Timestamp: $(date)"
    echo "Hostname: $(hostname)"
    echo "IP Address: $(hostname -I | awk '{print $1}')"
    echo "Gateway: $GATEWAY"
    echo "DNS Server: $DNS_SERVER"
    echo ""
    echo "For detailed logs, check system logs:"
    echo "  - /var/log/syslog"
    echo "  - journalctl -u openvpn"
    echo "  - journalctl -u networking"
}

# Main function
main() {
    echo "========================================"
    echo "    Homelab Network Diagnostics"
    echo "========================================"
    echo ""
    
    test_connectivity
    echo ""
    test_dns
    echo ""
    test_vpn
    echo ""
    test_routing
    echo ""
    test_firewall
    echo ""
    test_services
    echo ""
    test_nfs
    echo ""
    generate_summary
}

# Run diagnostics
main "$@"
