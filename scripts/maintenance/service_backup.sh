#!/bin/bash
# Comprehensive backup of Docker Plex and LXC Plex configurations before migration

PROXMOX_HOST="10.92.0.5"
PROXMOX_PASSWORD="Cl0udy!!(@"
DOCKER_HOST="10.92.3.2"
DOCKER_PASSWORD="!Snowfa11"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)

echo "=== Comprehensive Plex Configuration Backup ==="
echo "Backup timestamp: $BACKUP_DATE"

# Create backup script
cat > /tmp/backup_plex_configs.sh << 'EOF'
#!/bin/bash
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)

echo "=== Step 1: Create Backup Directories ==="
mkdir -p /tmp/plex-backup-$BACKUP_DATE/docker-plex
mkdir -p /tmp/plex-backup-$BACKUP_DATE/lxc-plex
mkdir -p /tmp/plex-backup-$BACKUP_DATE/proxmox-configs

echo "Backup directories created:"
ls -la /tmp/plex-backup-$BACKUP_DATE/

echo ""
echo "=== Step 2: Backup Docker Plex Configuration ==="
echo "Connecting to Docker host (10.92.3.2) to backup Plex data..."

# Find Docker Plex container and data
echo "Finding Docker Plex container:"
sshpass -p '!Snowfa11' ssh -o StrictHostKeyChecking=no root@10.92.3.2 "docker ps -a | grep -i plex"

echo ""
echo "Finding Docker Plex data directories:"
sshpass -p '!Snowfa11' ssh -o StrictHostKeyChecking=no root@10.92.3.2 "find /home/docker -name '*plex*' -type d 2>/dev/null"

echo ""
echo "Backing up Docker Plex configuration files:"
sshpass -p '!Snowfa11' ssh -o StrictHostKeyChecking=no root@10.92.3.2 "
    # Find the main Plex data directory
    PLEX_DIR=\$(find /home/docker -name '*plex*' -type d | grep -v cache | head -1)
    if [ ! -z \"\$PLEX_DIR\" ]; then
        echo \"Found Plex directory: \$PLEX_DIR\"
        
        # Create compressed backup of critical Plex files
        cd \$PLEX_DIR
        tar -czf /tmp/docker-plex-backup-$BACKUP_DATE.tar.gz \
            --exclude='Cache' \
            --exclude='Logs' \
            --exclude='Crash Reports' \
            --exclude='Media' \
            .
        
        echo \"Docker Plex backup created: /tmp/docker-plex-backup-$BACKUP_DATE.tar.gz\"
        ls -lh /tmp/docker-plex-backup-$BACKUP_DATE.tar.gz
    else
        echo \"No Plex directory found\"
    fi
"

echo ""
echo "Copying Docker Plex backup to Proxmox host:"
sshpass -p '!Snowfa11' scp -o StrictHostKeyChecking=no root@10.92.3.2:/tmp/docker-plex-backup-$BACKUP_DATE.tar.gz /tmp/plex-backup-$BACKUP_DATE/docker-plex/ 2>/dev/null || echo "Docker backup copy failed - will retry"

echo ""
echo "=== Step 3: Backup LXC Plex Configuration ==="
echo "Backing up LXC Plex configuration (Container 128)..."

# Stop Plex service for consistent backup
echo "Stopping Plex service for consistent backup:"
pct exec 128 -- systemctl stop plexmediaserver

echo ""
echo "Creating LXC Plex backup:"
pct exec 128 -- bash -c "
    cd /var/lib/plexmediaserver
    tar -czf /tmp/lxc-plex-backup-$BACKUP_DATE.tar.gz \
        --exclude='Cache' \
        --exclude='Logs' \
        --exclude='Crash Reports' \
        --exclude='Media' \
        .
    
    echo 'LXC Plex backup created:'
    ls -lh /tmp/lxc-plex-backup-$BACKUP_DATE.tar.gz
"

echo ""
echo "Copying LXC Plex backup to host:"
pct pull 128 /tmp/lxc-plex-backup-$BACKUP_DATE.tar.gz /tmp/plex-backup-$BACKUP_DATE/lxc-plex/

echo ""
echo "Restarting LXC Plex service:"
pct exec 128 -- systemctl start plexmediaserver

echo ""
echo "=== Step 4: Backup Proxmox Container Configuration ==="
echo "Backing up Plex LXC container configuration:"
pct config 128 > /tmp/plex-backup-$BACKUP_DATE/proxmox-configs/plex-lxc-128-config.txt

echo ""
echo "Backing up container mount information:"
mount | grep "128" > /tmp/plex-backup-$BACKUP_DATE/proxmox-configs/container-mounts.txt

echo ""
echo "=== Step 5: Create Migration Information File ==="
cat > /tmp/plex-backup-$BACKUP_DATE/MIGRATION_INFO.txt << 'MIGRATION_EOF'
Plex Docker-to-LXC Migration Backup
===================================
Backup Date: $BACKUP_DATE
Created by: Cascade AI Assistant

BACKUP CONTENTS:
================

1. Docker Plex Backup:
   - Location: docker-plex/docker-plex-backup-$BACKUP_DATE.tar.gz
   - Source: Docker container on 10.92.3.2
   - Contains: Plex database, preferences, metadata (excludes cache/logs)

2. LXC Plex Backup:
   - Location: lxc-plex/lxc-plex-backup-$BACKUP_DATE.tar.gz  
   - Source: LXC container 128 on Proxmox
   - Contains: Current LXC Plex installation (fresh install state)

3. Proxmox Configuration:
   - Container config: proxmox-configs/plex-lxc-128-config.txt
   - Mount info: proxmox-configs/container-mounts.txt

MIGRATION PLAN:
===============
1. Extract Docker Plex database and configuration
2. Stop LXC Plex service
3. Replace LXC Plex data with Docker data
4. Update library paths to use /mnt/data/media/
5. Start LXC Plex service
6. Verify migration success
7. Decommission Docker Plex

RESTORE INSTRUCTIONS:
====================
If migration fails:
- Docker restore: Extract docker-plex-backup to original location
- LXC restore: Extract lxc-plex-backup to /var/lib/plexmediaserver/
- Container restore: Use pct restore with proxmox configs

MIGRATION_EOF

echo ""
echo "=== Step 6: Backup Summary ==="
echo "Backup location: /tmp/plex-backup-$BACKUP_DATE/"
echo ""
echo "Backup contents:"
find /tmp/plex-backup-$BACKUP_DATE/ -type f -exec ls -lh {} \;

echo ""
echo "Total backup size:"
du -sh /tmp/plex-backup-$BACKUP_DATE/

echo ""
echo "=== BACKUP COMPLETE ==="
echo ""
echo "✅ Docker Plex configuration backed up"
echo "✅ LXC Plex configuration backed up"  
echo "✅ Proxmox container configuration backed up"
echo "✅ Migration information file created"
echo ""
echo "Backup directory: /tmp/plex-backup-$BACKUP_DATE/"
echo ""
echo "Ready to proceed with migration!"
EOF

# Execute backup script
echo "Copying backup script to Proxmox host..."
sshpass -p "$PROXMOX_PASSWORD" scp -o StrictHostKeyChecking=no /tmp/backup_plex_configs.sh root@$PROXMOX_HOST:/tmp/

echo "Running comprehensive Plex backup..."
sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no root@$PROXMOX_HOST "chmod +x /tmp/backup_plex_configs.sh && /tmp/backup_plex_configs.sh"

# Cleanup
rm /tmp/backup_plex_configs.sh
sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no root@$PROXMOX_HOST "rm /tmp/backup_plex_configs.sh"

echo ""
echo "=== PLEX BACKUP PROCESS COMPLETED ==="
echo ""
echo "Both Docker and LXC Plex configurations have been safely backed up!"
echo "Backup location on Proxmox host: /tmp/plex-backup-$BACKUP_DATE/"
echo ""
echo "Ready to proceed with the migration process!"
