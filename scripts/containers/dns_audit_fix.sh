#!/bin/bash
# Audit and fix DNS configuration for all LXC containers to use 10.92.0.10

# Connection details
PROXMOX_HOST="10.92.0.5"
PROXMOX_PASSWORD="Cl0udy!!(@"

echo "Auditing and fixing DNS configuration for all LXC containers..."

# Create comprehensive DNS audit and fix expect script
cat > /tmp/dns_audit_all.exp << 'EOF'
#!/usr/bin/expect -f
log_user 1
set timeout 30
set proxmox_host [lindex $argv 0]
set proxmox_password [lindex $argv 1]

spawn ssh -o StrictHostKeyChecking=no root@$proxmox_host
expect "password:"
send "$proxmox_password\r"
expect "root@*"

# Get list of all running LXC containers
send "echo '=== Getting List of All LXC Containers ==='\r"
expect "root@*"
send "pct list\r"
expect "root@*"

# Get container IDs for processing
send "echo ''\r"
expect "root@*"
send "echo '=== Processing Each Container ==='\r"
expect "root@*"

# Process each container individually
set container_ids {111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127}

foreach container_id $container_ids {
    send "echo ''\r"
    expect "root@*"
    send "echo '=== Container $container_id ==='\r"
    expect "root@*"
    
    # Check if container is running
    send "pct status $container_id\r"
    expect "root@*"
    
    # Get container name
    send "pct config $container_id | grep hostname || echo 'No hostname found'\r"
    expect "root@*"
    
    # Enter container if running
    send "if pct status $container_id | grep -q running; then echo 'Container running - checking DNS'; pct enter $container_id; else echo 'Container not running - skipping'; fi\r"
    expect {
        "Container not running" {
            send "echo 'Skipped container $container_id (not running)'\r"
            expect "root@*"
        }
        "root@*" {
            # We're now inside the container
            send "echo 'Current DNS config for container $container_id:'\r"
            expect "root@*"
            send "cat /etc/resolv.conf\r"
            expect "root@*"
            
            # Check if DNS needs fixing
            send "if grep -q '10.92.0.10' /etc/resolv.conf; then echo 'DNS already correct'; else echo 'DNS needs fixing'; fi\r"
            expect {
                "DNS already correct" {
                    send "echo 'Container $container_id: DNS OK'\r"
                    expect "root@*"
                }
                "DNS needs fixing" {
                    send "echo 'Fixing DNS for container $container_id...'\r"
                    expect "root@*"
                    send "cp /etc/resolv.conf /etc/resolv.conf.backup-$(date +%Y%m%d)\r"
                    expect "root@*"
                    send "echo 'nameserver 10.92.0.10' > /etc/resolv.conf\r"
                    expect "root@*"
                    send "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf\r"
                    expect "root@*"
                    send "echo 'nameserver 1.1.1.1' >> /etc/resolv.conf\r"
                    expect "root@*"
                    send "echo 'Updated DNS config:'\r"
                    expect "root@*"
                    send "cat /etc/resolv.conf\r"
                    expect "root@*"
                    send "echo 'Testing DNS resolution:'\r"
                    expect "root@*"
                    send "nslookup google.com | head -5\r"
                    expect "root@*"
                }
            }
            
            # Exit container
            send "exit\r"
            expect "root@*"
        }
    }
}

send "echo ''\r"
expect "root@*"
send "echo '=== DNS AUDIT AND FIX SUMMARY ==='\r"
expect "root@*"
send "echo 'All running LXC containers have been processed'\r"
expect "root@*"
send "echo 'DNS configuration updated to use:'\r"
expect "root@*"
send "echo '  Primary: 10.92.0.10'\r"
expect "root@*"
send "echo '  Fallback: 8.8.8.8, 1.1.1.1'\r"
expect "root@*"
send "echo 'Backup files created as /etc/resolv.conf.backup-YYYYMMDD'\r"
expect "root@*"

send "exit\r"
expect eof
EOF

chmod +x /tmp/dns_audit_all.exp
/tmp/dns_audit_all.exp $PROXMOX_HOST $PROXMOX_PASSWORD
rm /tmp/dns_audit_all.exp

echo "DNS audit and fix for all LXC containers completed!"
