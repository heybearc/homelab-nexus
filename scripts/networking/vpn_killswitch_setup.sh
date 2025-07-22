#!/bin/bash
# Script to complete VPN configuration on SABnzbd container

# From infrastructure spec
PROXMOX_HOST="10.92.0.5"
PROXMOX_PASSWORD="Cl0udy!!(@"
SABNZBD_ID="127"
PIA_USERNAME="p5100894"
PIA_PASSWORD="v3QzWLpFPB"
PIA_SERVER="185.242.4.2"
PIA_PORT="1198"

echo "Completing VPN configuration on SABnzbd container..."

# Create expect script to complete VPN setup
cat > /tmp/complete_vpn.exp << 'EOF'
#!/usr/bin/expect -f
log_user 1
set timeout 120
set host [lindex $argv 0]
set password [lindex $argv 1]
set container_id [lindex $argv 2]
set pia_username [lindex $argv 3]
set pia_password [lindex $argv 4]
set pia_server [lindex $argv 5]
set pia_port [lindex $argv 6]

# Connect to Proxmox host
spawn ssh -o StrictHostKeyChecking=no root@$host

# Handle password prompt
expect {
    "password:" { send "$password\r"; exp_continue }
    "root@*" { }
    timeout { puts "Connection timed out"; exit 1 }
}

# Enter the SABnzbd container
send "pct enter $container_id\r"
expect {
    "root@*" { }
    timeout { puts "Failed to enter container"; exit 1 }
}

# Go to PIA directory
send "cd /etc/openvpn/pia\r"
expect "root@*"

# Create PIA credentials file
send "echo '=== Creating PIA credentials file ==='\r"
expect "root@*"
send "echo '$pia_username' > credentials\r"
expect "root@*"
send "echo '$pia_password' >> credentials\r"
expect "root@*"
send "chmod 600 credentials\r"
expect "root@*"

# Download PIA certificates
send "echo '=== Downloading PIA certificates ==='\r"
expect "root@*"
send "curl -o ca.rsa.2048.crt https://www.privateinternetaccess.com/openvpn/ca.rsa.2048.crt\r"
expect "root@*"
send "curl -o crl.rsa.2048.pem https://www.privateinternetaccess.com/openvpn/crl.rsa.2048.pem\r"
expect "root@*"

# Create OpenVPN configuration
send "echo '=== Creating OpenVPN configuration ==='\r"
expect "root@*"
send "cat > /etc/openvpn/pia.conf << 'VPNCONF'\r"
send "client\r"
send "dev tun\r"
send "proto udp\r"
send "remote $pia_server $pia_port\r"
send "resolv-retry infinite\r"
send "nobind\r"
send "persist-key\r"
send "persist-tun\r"
send "cipher aes-128-cbc\r"
send "auth sha1\r"
send "tls-client\r"
send "remote-cert-tls server\r"
send "auth-user-pass /etc/openvpn/pia/credentials\r"
send "comp-lzo\r"
send "verb 1\r"
send "reneg-sec 0\r"
send "crl-verify /etc/openvpn/pia/crl.rsa.2048.pem\r"
send "ca /etc/openvpn/pia/ca.rsa.2048.crt\r"
send "disable-occ\r"
send "route-noexec\r"
send "script-security 2\r"
send "up /etc/openvpn/up.sh\r"
send "down /etc/openvpn/down.sh\r"
send "VPNCONF\r"
expect "root@*"

# Create routing scripts that preserve SSH access
send "echo '=== Creating routing scripts ==='\r"
expect "root@*"
send "cat > /etc/openvpn/up.sh << 'UPSCRIPT'\r"
send "#!/bin/bash\r"
send "# Preserve local network routing for SSH access\r"
send "ip route add 10.92.3.0/24 via \$route_net_gateway dev \$dev\r"
send "# Route external traffic through VPN\r"
send "ip route add 0.0.0.0/1 via \$route_vpn_gateway dev \$dev\r"
send "ip route add 128.0.0.0/1 via \$route_vpn_gateway dev \$dev\r"
send "# Preserve internal DNS\r"
send "echo 'nameserver 10.92.0.10' > /etc/resolv.conf\r"
send "UPSCRIPT\r"
expect "root@*"

send "cat > /etc/openvpn/down.sh << 'DOWNSCRIPT'\r"
send "#!/bin/bash\r"
send "# Clean up routes\r"
send "ip route del 10.92.3.0/24 2>/dev/null || true\r"
send "ip route del 0.0.0.0/1 2>/dev/null || true\r"
send "ip route del 128.0.0.0/1 2>/dev/null || true\r"
send "DOWNSCRIPT\r"
expect "root@*"

# Make scripts executable
send "chmod +x /etc/openvpn/up.sh /etc/openvpn/down.sh\r"
expect "root@*"

# Enable and start OpenVPN service
send "echo '=== Starting OpenVPN service ==='\r"
expect "root@*"
send "systemctl enable openvpn@pia\r"
expect "root@*"
send "systemctl start openvpn@pia\r"
expect "root@*"

# Wait for VPN to connect
send "sleep 15\r"
expect "root@*"

# Check VPN status
send "echo '=== Checking VPN status ==='\r"
expect "root@*"
send "systemctl status openvpn@pia\r"
expect "root@*"

# Check for VPN interface
send "echo '=== Checking VPN interface ==='\r"
expect "root@*"
send "ip addr show tun0 || echo 'No VPN interface found'\r"
expect "root@*"

# Test VPN connectivity
send "echo '=== Testing VPN connectivity ==='\r"
expect "root@*"
send "curl -s --connect-timeout 10 ifconfig.me || echo 'VPN connectivity test failed'\r"
expect "root@*"

# Check routing table
send "echo '=== Final routing table ==='\r"
expect "root@*"
send "ip route\r"
expect "root@*"

# Exit container and test SSH
send "exit\r"
expect "root@*"
send "echo '=== Testing SSH connectivity from Proxmox host ==='\r"
expect "root@*"
send "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@10.92.3.16 'echo \"SSH OK\"' || echo 'SSH Failed'\r"
expect "root@*"

# Exit Proxmox host
send "exit\r"
expect eof
EOF

# Make expect script executable
chmod +x /tmp/complete_vpn.exp

# Run expect script
/tmp/complete_vpn.exp $PROXMOX_HOST $PROXMOX_PASSWORD $SABNZBD_ID $PIA_USERNAME $PIA_PASSWORD $PIA_SERVER $PIA_PORT

# Clean up
rm /tmp/complete_vpn.exp

echo "VPN configuration completed."
