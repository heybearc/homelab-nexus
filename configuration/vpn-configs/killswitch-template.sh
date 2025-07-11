#!/bin/bash
# VPN Killswitch Script Template
# Blocks all traffic except VPN and local network access

# Configuration
VPN_INTERFACE="tun0"
LOCAL_NETWORK="10.92.0.0/16"
SSH_PORT="22"
SERVICE_PORTS="8080 9090 8989 7878"  # Adjust for specific service

# Function to setup killswitch rules
setup_killswitch() {
    echo "Setting up VPN killswitch..."
    
    # Flush existing rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    # Default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow local network access (SSH and service ports)
    iptables -A INPUT -s $LOCAL_NETWORK -p tcp --dport $SSH_PORT -j ACCEPT
    iptables -A OUTPUT -d $LOCAL_NETWORK -p tcp --sport $SSH_PORT -j ACCEPT
    
    # Allow service ports from local network
    for port in $SERVICE_PORTS; do
        iptables -A INPUT -s $LOCAL_NETWORK -p tcp --dport $port -j ACCEPT
        iptables -A OUTPUT -d $LOCAL_NETWORK -p tcp --sport $port -j ACCEPT
    done
    
    # Allow DNS to local DNS server
    iptables -A OUTPUT -d 10.92.0.10 -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -s 10.92.0.10 -p udp --sport 53 -j ACCEPT
    
    # Allow VPN interface traffic
    iptables -A INPUT -i $VPN_INTERFACE -j ACCEPT
    iptables -A OUTPUT -o $VPN_INTERFACE -j ACCEPT
    
    # Allow VPN connection establishment
    iptables -A OUTPUT -p udp --dport 1198 -j ACCEPT
    iptables -A INPUT -p udp --sport 1198 -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    echo "VPN killswitch activated"
}

# Function to remove killswitch rules
remove_killswitch() {
    echo "Removing VPN killswitch..."
    
    # Flush all rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    # Set default policies to ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    echo "VPN killswitch removed"
}

# Function to check VPN status
check_vpn_status() {
    if ip link show $VPN_INTERFACE &> /dev/null; then
        echo "VPN interface $VPN_INTERFACE is UP"
        return 0
    else
        echo "VPN interface $VPN_INTERFACE is DOWN"
        return 1
    fi
}

# Main script logic
case "$1" in
    start)
        setup_killswitch
        ;;
    stop)
        remove_killswitch
        ;;
    status)
        check_vpn_status
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac

exit 0
