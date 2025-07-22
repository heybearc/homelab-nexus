#!/bin/bash
# Check LXC container 127 IP address

# Connection details
PROXMOX_HOST="10.92.0.5"
PROXMOX_PASSWORD="Cl0udy!!(@"
SABNZBD_LXC_ID="127"

echo "Checking LXC container 127 IP address..."

# Create IP check expect script
cat > /tmp/ip_check.exp << 'EOF'
#!/usr/bin/expect -f
log_user 1
set timeout 20
set proxmox_host [lindex $argv 0]
set proxmox_password [lindex $argv 1]
set lxc_id [lindex $argv 2]

spawn ssh -o StrictHostKeyChecking=no root@$proxmox_host
expect "password:"
send "$proxmox_password\r"
expect "root@*"

# Check LXC container IP from Proxmox host
send "echo '=== LXC Container 127 IP Address ==='\r"
expect "root@*"
send "pct list | grep $lxc_id\r"
expect "root@*"

# Get detailed network info
send "pct config $lxc_id | grep net\r"
expect "root@*"

# Enter container to check IP from inside
send "pct enter $lxc_id\r"
expect "root@*"

send "echo '=== IP Address from inside container ==='\r"
expect "root@*"
send "ip addr show | grep 'inet '\r"
expect "root@*"

send "echo '=== Hostname and network test ==='\r"
expect "root@*"
send "hostname -I\r"
expect "root@*"

send "echo '=== SABnzbd Web Interface URLs ==='\r"
expect "root@*"
send "CONTAINER_IP=\\$(hostname -I | awk '{print \\$1}')\r"
expect "root@*"
send "echo \"Primary URL: http://\\$CONTAINER_IP:7777\"\r"
expect "root@*"
send "echo \"API Key: 967726d571ad492d8bb2bae7cda0d903\"\r"
expect "root@*"
send "echo \"Local URL: http://localhost:7777 (from within container)\"\r"
expect "root@*"

send "exit\r"
expect "root@*"
send "exit\r"
expect eof
EOF

chmod +x /tmp/ip_check.exp
/tmp/ip_check.exp $PROXMOX_HOST $PROXMOX_PASSWORD $SABNZBD_LXC_ID
rm /tmp/ip_check.exp

echo "IP address check completed!"
