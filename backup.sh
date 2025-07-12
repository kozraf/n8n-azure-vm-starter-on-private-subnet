#!/bin/bash

# Configuration variables
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_BACKUP_FILE="backup_${TIMESTAMP}.sql"
DATA_BACKUP_FILE="n8n_data_${TIMESTAMP}.tar.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting backup process at $(date)"

# Backup PostgreSQL database
echo "Backing up PostgreSQL database..."
if docker exec n8n-postgres-1 pg_dump -U n8n n8n > "$BACKUP_DIR/$DB_BACKUP_FILE"; then
    echo "Database backup completed: $DB_BACKUP_FILE"
else
    echo "Error: Database backup failed" >&2
    exit 1
fi

# Backup n8n data volume
echo "Backing up n8n data volume..."
if tar -czf "$BACKUP_DIR/$DATA_BACKUP_FILE" -C /var/lib/docker/volumes/n8n_n8n_data .; then
    echo "Data volume backup completed: $DATA_BACKUP_FILE"
else
    echo "Error: Data volume backup failed" >&2
    exit 1
fi

# Clean up old backups (optional)
if [ "$RETENTION_DAYS" -gt 0 ]; then
    echo "Cleaning up backups older than $RETENTION_DAYS days..."
    find "$BACKUP_DIR" -name "backup_*.sql" -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "n8n_data_*.tar.gz" -mtime +$RETENTION_DAYS -delete
fi

# Upload to Azure Storage (optional - configure as needed)
if [ -n "$AZURE_STORAGE_ACCOUNT" ] && [ -n "$AZURE_STORAGE_CONTAINER" ]; then
    echo "Uploading to Azure Storage..."
    az storage blob upload \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --container-name "$AZURE_STORAGE_CONTAINER" \
        --name "database/$DB_BACKUP_FILE" \
        --file "$BACKUP_DIR/$DB_BACKUP_FILE" \
        --overwrite
    
    az storage blob upload \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --container-name "$AZURE_STORAGE_CONTAINER" \
        --name "data/$DATA_BACKUP_FILE" \
        --file "$BACKUP_DIR/$DATA_BACKUP_FILE" \
        --overwrite
    
    echo "Azure Storage upload completed"
else
    echo "Azure Storage configuration not found - backups saved locally only"
fi

echo "Backup process completed at $(date)" 