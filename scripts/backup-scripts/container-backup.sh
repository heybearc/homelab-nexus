#!/bin/bash
# Container Backup Script
# Automated backup for Proxmox LXC containers

# Configuration
BACKUP_DIR="/var/lib/vz/dump"
RETENTION_DAYS=30
LOG_FILE="/var/log/container-backup.log"
PROXMOX_HOST="10.92.0.5"

# Container IDs to backup (adjust as needed)
CONTAINERS=(112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127)

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to backup a single container
backup_container() {
    local container_id=$1
    log_message "Starting backup for container $container_id"
    
    if pct status $container_id | grep -q "running"; then
        # Container is running, create snapshot backup
        vzdump $container_id --mode snapshot --storage local --compress lzo --remove 0
    else
        # Container is stopped, create regular backup
        vzdump $container_id --mode stop --storage local --compress lzo --remove 0
    fi
    
    if [ $? -eq 0 ]; then
        log_message "Backup completed successfully for container $container_id"
    else
        log_message "ERROR: Backup failed for container $container_id"
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    log_message "Cleaning up backups older than $RETENTION_DAYS days"
    find "$BACKUP_DIR" -name "vzdump-lxc-*.tar.lzo" -mtime +$RETENTION_DAYS -delete
    log_message "Cleanup completed"
}

# Main backup process
main() {
    log_message "Starting container backup process"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Backup each container
    for container_id in "${CONTAINERS[@]}"; do
        backup_container $container_id
        sleep 10  # Brief pause between backups
    done
    
    # Cleanup old backups
    cleanup_old_backups
    
    log_message "Container backup process completed"
}

# Run main function
main "$@"
