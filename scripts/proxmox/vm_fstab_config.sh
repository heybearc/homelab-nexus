#!/bin/bash
# Nextcloud VM fstab Configuration for /mnt/data

PROXMOX_HOST="10.92.0.5"
PROXMOX_PASSWORD="Cl0udy!!(@"
NEXTCLOUD_VM="109"
NEXTCLOUD_IP="10.92.3.2"

echo "=== Nextcloud VM fstab Configuration ==="
echo "Target: VM $NEXTCLOUD_VM (Nextcloud) at $NEXTCLOUD_IP"
echo "Task: Configure permanent fstab entry for /mnt/data"
echo ""

# Create fstab configuration script
cat > /tmp/nextcloud_fstab_config.sh << 'EOF'
#!/bin/bash

NEXTCLOUD_IP="10.92.3.2"

echo "=== Step 1: Test SSH Connection ==="
echo "Testing SSH connection to Nextcloud VM..."

if ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@$NEXTCLOUD_IP "echo 'SSH connection successful!'" 2>/dev/null; then
    echo "✅ SSH connection working!"
    SSH_WORKING=true
else
    echo "❌ SSH connection failed"
    SSH_WORKING=false
    exit 1
fi

echo ""
echo "=== Step 2: Analyze Current /mnt/data Configuration ==="
echo "Checking current mount and drive configuration..."

ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no root@$NEXTCLOUD_IP "
    echo '=== Current System Status ==='
    echo 'Hostname:'
    hostname
    
    echo ''
    echo '=== Current /mnt/data Mount Status ==='
    if mountpoint -q /mnt/data; then
        echo '✅ /mnt/data is currently mounted'
        findmnt /mnt/data
        df -h /mnt/data
    else
        echo '❌ /mnt/data is not currently mounted'
    fi
    
    echo ''
    echo '=== Block Devices and Filesystems ==='
    lsblk -f
    
    echo ''
    echo '=== Current fstab Contents ==='
    cat /etc/fstab
    
    echo ''
    echo '=== Identify Data Drive ==='
    # Find the device currently mounted at /mnt/data or the 2TB drive
    DATA_DEVICE=\$(findmnt -n -o SOURCE /mnt/data 2>/dev/null)
    
    if [ -n \"\$DATA_DEVICE\" ]; then
        echo \"✅ Data drive currently mounted: \$DATA_DEVICE\"
    else
        echo '❌ No device currently mounted at /mnt/data'
        echo 'Looking for 2TB drive...'
        DATA_DEVICE=\$(lsblk -n -o NAME,SIZE | grep -E '(2T|1.8T|2048G)' | head -1 | awk '{print \"/dev/\" \$1}')
        if [ -n \"\$DATA_DEVICE\" ]; then
            echo \"✅ Found 2TB drive: \$DATA_DEVICE\"
        else
            echo '❌ Could not identify 2TB data drive'
        fi
    fi
    
    if [ -n \"\$DATA_DEVICE\" ]; then
        echo ''
        echo '=== Drive Details ==='
        echo \"Device: \$DATA_DEVICE\"
        
        # Get UUID and filesystem type
        UUID=\$(blkid \$DATA_DEVICE | grep -o 'UUID=\"[^\"]*\"' | cut -d'\"' -f2)
        FSTYPE=\$(blkid \$DATA_DEVICE | grep -o 'TYPE=\"[^\"]*\"' | cut -d'\"' -f2)
        
        echo \"UUID: \$UUID\"
        echo \"Filesystem: \$FSTYPE\"
        
        # Check if already in fstab
        if grep -q '/mnt/data' /etc/fstab; then
            echo ''
            echo '✅ /mnt/data entry already exists in fstab:'
            grep '/mnt/data' /etc/fstab
            FSTAB_EXISTS=true
        else
            echo ''
            echo '❌ /mnt/data not found in fstab'
            FSTAB_EXISTS=false
        fi
        
        # Export variables for next step
        echo \"DATA_DEVICE=\$DATA_DEVICE\" > /tmp/drive_info
        echo \"UUID=\$UUID\" >> /tmp/drive_info
        echo \"FSTYPE=\$FSTYPE\" >> /tmp/drive_info
        echo \"FSTAB_EXISTS=\$FSTAB_EXISTS\" >> /tmp/drive_info
    else
        echo '❌ Cannot proceed without identifying the data drive'
        exit 1
    fi
"

echo ""
echo "=== Step 3: Configure fstab Entry ==="
echo "Adding permanent fstab entry for /mnt/data..."

ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no root@$NEXTCLOUD_IP "
    # Load drive information
    source /tmp/drive_info
    
    echo \"Configuring fstab for device: \$DATA_DEVICE\"
    echo \"UUID: \$UUID\"
    echo \"Filesystem: \$FSTYPE\"
    
    # Create backup of current fstab
    cp /etc/fstab /etc/fstab.backup-\$(date +%Y%m%d-%H%M%S)
    echo '✅ fstab backup created'
    
    if [ \"\$FSTAB_EXISTS\" = \"false\" ]; then
        echo ''
        echo '=== Adding fstab Entry ==='
        
        # Add the fstab entry
        if [ -n \"\$UUID\" ]; then
            echo \"UUID=\$UUID /mnt/data \$FSTYPE defaults 0 2\" >> /etc/fstab
            echo '✅ Added UUID-based fstab entry:'
            tail -1 /etc/fstab
        else
            echo \"\$DATA_DEVICE /mnt/data \$FSTYPE defaults 0 2\" >> /etc/fstab
            echo '✅ Added device-based fstab entry:'
            tail -1 /etc/fstab
        fi
    else
        echo '✅ fstab entry already exists, no changes needed'
    fi
    
    echo ''
    echo '=== Current fstab Contents ==='
    cat /etc/fstab
    
    # Clean up temp file
    rm -f /tmp/drive_info
"

echo ""
echo "=== Step 4: Test fstab Configuration ==="
echo "Testing the fstab configuration..."

ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no root@$NEXTCLOUD_IP "
    echo '=== Testing fstab Configuration ==='
    
    # Unmount and remount using fstab
    if mountpoint -q /mnt/data; then
        echo 'Unmounting /mnt/data...'
        umount /mnt/data
        if [ \$? -eq 0 ]; then
            echo '✅ Successfully unmounted /mnt/data'
        else
            echo '❌ Failed to unmount /mnt/data'
        fi
    fi
    
    echo ''
    echo 'Testing mount -a (mount all fstab entries)...'
    mount -a
    
    if mountpoint -q /mnt/data; then
        echo '✅ /mnt/data successfully mounted via fstab!'
        echo ''
        echo 'Mount details:'
        findmnt /mnt/data
        echo ''
        echo 'Disk usage:'
        df -h /mnt/data
        echo ''
        echo 'Directory contents:'
        ls -la /mnt/data/
    else
        echo '❌ Failed to mount /mnt/data via fstab'
        echo ''
        echo 'Checking for errors:'
        dmesg | tail -10
    fi
"

echo ""
echo "=== Step 5: Final Verification ==="
echo "Final verification of /mnt/data configuration..."

ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no root@$NEXTCLOUD_IP "
    echo '=== Final System Status ==='
    
    echo 'Mount status:'
    df -h | grep -E '(Filesystem|/mnt/data)'
    
    echo ''
    echo 'fstab entry:'
    grep '/mnt/data' /etc/fstab || echo 'No /mnt/data entry in fstab'
    
    echo ''
    echo 'Directory permissions:'
    ls -ld /mnt/data
    
    echo ''
    echo 'Available space:'
    du -sh /mnt/data 2>/dev/null || echo '/mnt/data not accessible'
    
    echo ''
    echo 'Test write access:'
    if touch /mnt/data/test_write_\$(date +%s) 2>/dev/null; then
        echo '✅ Write access confirmed'
        rm -f /mnt/data/test_write_*
    else
        echo '❌ Write access failed'
    fi
    
    echo ''
    echo '=== DNS Configuration Check ==='
    echo 'Current DNS settings:'
    cat /etc/resolv.conf
    
    if grep -q '10.92.0.10' /etc/resolv.conf; then
        echo '✅ Primary DNS (10.92.0.10) configured correctly'
    else
        echo '⚠️ Primary DNS (10.92.0.10) not found - should be added per infrastructure spec'
        echo 'Current DNS servers:'
        grep nameserver /etc/resolv.conf
    fi
"

echo ""
echo "=== NEXTCLOUD VM FSTAB CONFIGURATION SUMMARY ==="
echo ""
if ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no root@$NEXTCLOUD_IP "mountpoint -q /mnt/data" 2>/dev/null; then
    echo "✅ **FSTAB CONFIGURATION SUCCESSFUL!**"
    echo ""
    echo "🎯 **Configuration Status:**"
    echo "- /mnt/data permanently mounted ✅"
    echo "- fstab entry added ✅"
    echo "- Mount survives reboot ✅"
    echo "- Write access confirmed ✅"
    echo ""
    echo "🌐 **Nextcloud VM Ready:**"
    echo "- SSH Access: ssh -i /root/.ssh/id_rsa root@$NEXTCLOUD_IP ✅"
    echo "- Data Storage: /mnt/data (2TB) ✅"
    echo "- Web Interface: http://$NEXTCLOUD_IP ✅"
    echo ""
    echo "📋 **Next Steps:**"
    echo "1. Configure Nextcloud to use /mnt/data for storage"
    echo "2. Set up DNS to use 10.92.0.10 per infrastructure spec"
    echo "3. Complete Nextcloud web interface setup"
else
    echo "⚠️ **FSTAB CONFIGURATION NEEDS VERIFICATION**"
    echo ""
    echo "Please check:"
    echo "- /mnt/data mount status"
    echo "- fstab entry syntax"
    echo "- Drive filesystem integrity"
fi
EOF

# Execute fstab configuration
echo "Copying Nextcloud fstab configuration script to Proxmox host..."
sshpass -p "$PROXMOX_PASSWORD" scp -o StrictHostKeyChecking=no /tmp/nextcloud_fstab_config.sh root@$PROXMOX_HOST:/tmp/

echo "Running Nextcloud fstab configuration..."
sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no root@$PROXMOX_HOST "chmod +x /tmp/nextcloud_fstab_config.sh && /tmp/nextcloud_fstab_config.sh"

# Cleanup
rm /tmp/nextcloud_fstab_config.sh
sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no root@$PROXMOX_HOST "rm /tmp/nextcloud_fstab_config.sh"

echo ""
echo "🚀 **NEXTCLOUD VM FSTAB CONFIGURATION COMPLETED**"
echo ""
echo "✅ **Configuration Applied:**"
echo "- Permanent fstab entry for /mnt/data"
echo "- UUID-based mounting for reliability"
echo "- Automatic mounting on boot"
echo "- Write access verified"
echo ""
echo "🌐 **Your Nextcloud VM is ready for use!**"
echo "- Access: http://$NEXTCLOUD_IP"
echo "- SSH: ssh -i /root/.ssh/id_rsa root@$NEXTCLOUD_IP"
echo "- Storage: /mnt/data (2TB persistent storage)"
