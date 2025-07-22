#!/bin/bash
# Deep network diagnosis for SABnzbd container 127

# Connection details
PROXMOX_HOST="10.92.0.5"
PROXMOX_PASSWORD="Cl0udy!!(@"
SABNZBD_LXC_ID="127"

echo "Deep network diagnosis for SABnzbd container 127..."

# Create deep network diagnostic expect script
cat > /tmp/deep_network.exp << 'EOF'
#!/usr/bin/expect -f
log_user 1
set timeout 30
set proxmox_host [lindex $argv 0]
set proxmox_password [lindex $argv 1]
set lxc_id [lindex $argv 2]

spawn ssh -o StrictHostKeyChecking=no root@$proxmox_host
expect "password:"
send "$proxmox_password\r"
expect "root@*"

# Check Proxmox host network bridges
send "echo '=== Proxmox Host Network Bridges ==='\r"
expect "root@*"
send "brctl show\r"
expect "root@*"

# Check if vmbr923 bridge exists and is configured
send "echo ''\r"
expect "root@*"
send "echo '=== Bridge vmbr923 Status ==='\r"
expect "root@*"
send "ip addr show vmbr923\r"
expect "root@*"

# Check bridge forwarding
send "echo ''\r"
expect "root@*"
send "echo '=== Bridge Forwarding Status ==='\r"
expect "root@*"
send "cat /proc/sys/net/bridge/bridge-nf-call-iptables\r"
expect "root@*"
send "cat /proc/sys/net/ipv4/ip_forward\r"
expect "root@*"

# Check container's veth interface on host
send "echo ''\r"
expect "root@*"
send "echo '=== Container veth Interface on Host ==='\r"
expect "root@*"
send "ip link show | grep -A2 -B2 'BC:24:11:70:FF:F9'\r"
expect "root@*"

# Check iptables rules on host
send "echo ''\r"
expect "root@*"
send "echo '=== Proxmox Host iptables Rules ==='\r"
expect "root@*"
send "iptables -L -n | head -20\r"
expect "root@*"

# Check if there are any rules blocking 10.92.3.16
send "echo ''\r"
expect "root@*"
send "echo '=== Rules affecting 10.92.3.16 ==='\r"
expect "root@*"
send "iptables -L -n | grep '10.92.3.16' || echo 'No specific rules for 10.92.3.16'\r"
expect "root@*"

# Check container network namespace
send "echo ''\r"
expect "root@*"
send "echo '=== Container Network Namespace ==='\r"
expect "root@*"
send "lxc-info -n $lxc_id | grep State\r"
expect "root@*"

# Enter container for internal network check
send "echo ''\r"
expect "root@*"
send "echo '=== Container Internal Network ==='\r"
expect "root@*"
send "pct enter $lxc_id\r"
expect "root@*"

# Check if container can reach its own gateway
send "echo 'Testing gateway from container:'\r"
expect "root@*"
send "ping -c 2 10.92.3.1\r"
expect "root@*"

# Check if container can reach Proxmox host
send "echo ''\r"
expect "root@*"
send "echo 'Testing Proxmox host from container:'\r"
expect "root@*"
send "ping -c 2 10.92.0.5\r"
expect "root@*"

# Check if container can reach other containers
send "echo ''\r"
expect "root@*"
send "echo 'Testing other container from SABnzbd:'\r"
expect "root@*"
send "ping -c 2 10.92.3.15\r"
expect "root@*"

# Check container's ARP table
send "echo ''\r"
expect "root@*"
send "echo 'Container ARP table:'\r"
expect "root@*"
send "arp -a\r"
expect "root@*"

# Check if there are any iptables rules in container
send "echo ''\r"
expect "root@*"
send "echo 'Container iptables rules:'\r"
expect "root@*"
send "iptables -L -n\r"
expect "root@*"

send "exit\r"
expect "root@*"

# Try to manually recreate the network interface
send "echo ''\r"
expect "root@*"
send "echo '=== Attempting Network Interface Reset ==='\r"
expect "root@*"
send "pct stop $lxc_id\r"
expect "root@*"
send "sleep 3\r"
expect "root@*"

# Check if veth interface is removed when container stops
send "echo 'Checking veth after stop:'\r"
expect "root@*"
send "ip link show | grep 'BC:24:11:70:FF:F9' || echo 'veth interface removed'\r"
expect "root@*"

# Start container and check if veth is recreated
send "echo ''\r"
expect "root@*"
send "echo 'Starting container and checking veth recreation:'\r"
expect "root@*"
send "pct start $lxc_id\r"
expect "root@*"
send "sleep 5\r"
expect "root@*"
send "ip link show | grep -A2 -B2 'BC:24:11:70:FF:F9'\r"
expect "root@*"

# Final connectivity test from Proxmox host
send "echo ''\r"
expect "root@*"
send "echo '=== Final Connectivity Test ==='\r"
expect "root@*"
send "ping -c 3 10.92.3.16\r"
expect "root@*"

send "echo ''\r"
expect "root@*"
send "echo '=== NETWORK DIAGNOSIS SUMMARY ==='\r"
expect "root@*"
send "echo 'Check above for:'\r"
expect "root@*"
send "echo '1. Bridge configuration (vmbr923)'\r"
expect "root@*"
send "echo '2. veth interface presence and status'\r"
expect "root@*"
send "echo '3. iptables rules blocking traffic'\r"
expect "root@*"
send "echo '4. Container internal connectivity'\r"
expect "root@*"
send "echo '5. Network namespace issues'\r"
expect "root@*"

send "exit\r"
expect eof
EOF

chmod +x /tmp/deep_network.exp
/tmp/deep_network.exp $PROXMOX_HOST $PROXMOX_PASSWORD $SABNZBD_LXC_ID
rm /tmp/deep_network.exp

echo "Deep network diagnosis completed!"
