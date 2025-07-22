#!/bin/bash
# Clean up any SABnzbd installation artifacts from Proxmox host

# Connection details
PROXMOX_HOST="10.92.0.5"
PROXMOX_PASSWORD="Cl0udy!!(@"

echo "Cleaning up SABnzbd installation artifacts from Proxmox host..."

# Create cleanup expect script
cat > /tmp/cleanup_proxmox.exp << 'EOF'
#!/usr/bin/expect -f
log_user 1
set timeout 60
set proxmox_host [lindex $argv 0]
set proxmox_password [lindex $argv 1]

# Connect to Proxmox host
spawn ssh -o StrictHostKeyChecking=no root@$proxmox_host

# Handle password prompt for Proxmox
expect {
    "password:" { send "$proxmox_password\r"; exp_continue }
    "root@*" { }
    timeout { puts "Connection to Proxmox timed out"; exit 1 }
}

# Clean up any SABnzbd artifacts on Proxmox host
send "echo '=== Cleaning up SABnzbd artifacts from Proxmox host ==='\r"
expect "root@*"

# Check for any SABnzbd processes on host (should not be any)
send "echo 'Checking for SABnzbd processes on Proxmox host...'\r"
expect "root@*"
send "ps aux | grep -i sabnzbd | grep -v grep\r"
expect "root@*"

# Remove any SABnzbd installation directories that might have been created
send "echo 'Removing any SABnzbd installation artifacts...'\r"
expect "root@*"
send "rm -rf /opt/sabnzbd 2>/dev/null || echo 'No /opt/sabnzbd to remove'\r"
expect "root@*"
send "rm -rf /usr/local/bin/sabnzbd 2>/dev/null || echo 'No /usr/local/bin/sabnzbd to remove'\r"
expect "root@*"
send "rm -rf /home/sabnzbd 2>/dev/null || echo 'No /home/sabnzbd to remove'\r"
expect "root@*"
send "rm -rf /var/lib/sabnzbd 2>/dev/null || echo 'No /var/lib/sabnzbd to remove'\r"
expect "root@*"

# Remove any systemd service files
send "echo 'Removing any SABnzbd systemd service files...'\r"
expect "root@*"
send "rm -f /etc/systemd/system/sabnzbd.service 2>/dev/null || echo 'No systemd service to remove'\r"
expect "root@*"
send "systemctl daemon-reload 2>/dev/null || echo 'Systemd reload done'\r"
expect "root@*"

# Remove any temporary files
send "echo 'Cleaning up temporary files...'\r"
expect "root@*"
send "rm -f /tmp/sabnzbd*.tar.gz /tmp/sabnzbd*.ini /tmp/*.cfg 2>/dev/null || echo 'Temp files cleaned'\r"
expect "root@*"

# Check if sabnzbd user was created and remove if needed
send "echo 'Checking for sabnzbd user...'\r"
expect "root@*"
send "id sabnzbd 2>/dev/null && userdel -r sabnzbd 2>/dev/null || echo 'No sabnzbd user to remove'\r"
expect "root@*"

# Verify cleanup
send "echo '=== Verifying cleanup ==='\r"
expect "root@*"
send "ps aux | grep -i sabnzbd | grep -v grep || echo 'No SABnzbd processes on host'\r"
expect "root@*"
send "ls -la /opt/sabnzbd 2>/dev/null || echo 'No /opt/sabnzbd directory'\r"
expect "root@*"
send "ls -la /etc/systemd/system/sabnzbd.service 2>/dev/null || echo 'No systemd service file'\r"
expect "root@*"

send "echo 'Proxmox host cleanup completed'\r"
expect "root@*"

# Exit Proxmox host
send "exit\r"
expect eof
EOF

# Make expect script executable
chmod +x /tmp/cleanup_proxmox.exp

# Run expect script
/tmp/cleanup_proxmox.exp $PROXMOX_HOST $PROXMOX_PASSWORD

# Clean up
rm /tmp/cleanup_proxmox.exp

echo "Proxmox host cleanup completed."
