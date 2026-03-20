#!/bin/bash
#
# Scrypted Database Backup Script
# Backs up Scrypted database to TrueNAS storage
#
# Usage: Run daily via cron on Proxmox host
# Cron: 0 3 * * * /root/backup-scrypted-db.sh

set -e

CONTAINER_ID="180"
BACKUP_DIR="/mnt/truenas-recordings/scrypted-backups"
DATE=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS=30

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup Scrypted database
echo "$(date): Starting Scrypted database backup..."

# Stop Scrypted temporarily for consistent backup
pct exec $CONTAINER_ID -- systemctl stop scrypted

# Create backup
pct exec $CONTAINER_ID -- tar -czf /tmp/scrypted-backup-$DATE.tar.gz \
    -C /root/.scrypted/volume scrypted.db plugins

# Copy backup to TrueNAS
pct exec $CONTAINER_ID -- cp /tmp/scrypted-backup-$DATE.tar.gz /mnt/recordings/scrypted-backups/

# Restart Scrypted
pct exec $CONTAINER_ID -- systemctl start scrypted

# Clean up temp file
pct exec $CONTAINER_ID -- rm /tmp/scrypted-backup-$DATE.tar.gz

# Remove old backups
find "$BACKUP_DIR" -name "scrypted-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "$(date): Backup completed: scrypted-backup-$DATE.tar.gz"
echo "$(date): Old backups older than $RETENTION_DAYS days removed"

# List current backups
echo "Current backups:"
ls -lh "$BACKUP_DIR"
