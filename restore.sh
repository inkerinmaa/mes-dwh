#!/usr/bin/env bash
# Restore the mes PostgreSQL database from a backup dump.
# Drops all existing objects and recreates them from the backup.
#
# Usage:
#   ./restore.sh <backup_file.dump>
#
# WARNING: All current data in the mes database will be replaced.

set -euo pipefail

BACKUP_FILE="${1:-}"

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.dump>" >&2
    exit 1
fi

echo "Restoring database mes from: $BACKUP_FILE"
echo "WARNING: All current data will be replaced. Ctrl+C within 5s to abort."
sleep 5

docker exec -i postgres-db pg_restore \
    -U mesrwl -d mes \
    --clean --if-exists \
    --no-owner --no-privileges \
    < "$BACKUP_FILE"

echo "Restore complete."
