#!/bin/bash
# NPM Database Backup Script
# Backs up NPM SQLite database to TrueNAS NFS storage
# Runs daily via cron at 2 AM

set -e

# Configuration
BACKUP_DIR="/mnt/pve/media-pool/backups/npm/database"
LOCAL_BACKUP_DIR="/hdd-pool/backups/npm-database"
DB_PATH="/hdd-pool/subvol-121-disk-0/data/database.sqlite"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="npm-database-$DATE.sqlite"
LOG_FILE="/var/log/npm-backup.log"
RETENTION_DAYS=60

# Ensure backup directories exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOCAL_BACKUP_DIR"

# Log start
echo "$(date): Starting NPM database backup" >> "$LOG_FILE"

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "$(date): ERROR - Database not found at $DB_PATH" >> "$LOG_FILE"
    exit 1
fi

# Backup to TrueNAS (primary)
echo "$(date): Backing up to TrueNAS: $BACKUP_DIR/$BACKUP_FILE" >> "$LOG_FILE"
if sqlite3 "$DB_PATH" ".backup '$BACKUP_DIR/$BACKUP_FILE'"; then
    gzip "$BACKUP_DIR/$BACKUP_FILE"
    echo "$(date): TrueNAS backup successful: $BACKUP_FILE.gz" >> "$LOG_FILE"
else
    echo "$(date): ERROR - TrueNAS backup failed" >> "$LOG_FILE"
    exit 1
fi

# Backup to local storage (redundancy)
echo "$(date): Creating local redundant backup" >> "$LOG_FILE"
if sqlite3 "$DB_PATH" ".backup '$LOCAL_BACKUP_DIR/$BACKUP_FILE'"; then
    gzip "$LOCAL_BACKUP_DIR/$BACKUP_FILE"
    echo "$(date): Local backup successful: $BACKUP_FILE.gz" >> "$LOG_FILE"
else
    echo "$(date): WARNING - Local backup failed (TrueNAS backup still successful)" >> "$LOG_FILE"
fi

# Cleanup old backups (TrueNAS)
echo "$(date): Cleaning up backups older than $RETENTION_DAYS days" >> "$LOG_FILE"
find "$BACKUP_DIR" -name "npm-database-*.sqlite.gz" -mtime +$RETENTION_DAYS -delete

# Cleanup old local backups (keep last 7 days)
find "$LOCAL_BACKUP_DIR" -name "npm-database-*.sqlite.gz" -mtime +7 -delete

# Verify backup integrity
if gunzip -t "$BACKUP_DIR/$BACKUP_FILE.gz" 2>/dev/null; then
    echo "$(date): Backup integrity verified" >> "$LOG_FILE"
else
    echo "$(date): ERROR - Backup integrity check failed" >> "$LOG_FILE"
    exit 1
fi

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE.gz" | cut -f1)
echo "$(date): Backup completed successfully - Size: $BACKUP_SIZE" >> "$LOG_FILE"

# Count proxy hosts for verification
PROXY_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM proxy_host WHERE enabled = 1 AND is_deleted = 0;")
echo "$(date): Verified $PROXY_COUNT active proxy hosts in database" >> "$LOG_FILE"

exit 0
