#!/usr/bin/env bash
# Backup the mes PostgreSQL database to a compressed custom-format dump.
#
# Usage:
#   ./backup.sh                  # saves to current directory
#   ./backup.sh /path/to/dir     # saves to specified directory
#
# Output file: mes_backup_YYYYMMDD_HHMMSS.dump

set -euo pipefail

OUTPUT_DIR="${1:-$(pwd)}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE="$OUTPUT_DIR/mes_backup_$TIMESTAMP.dump"

echo "Backing up database mes → $FILE ..."
docker exec postgres-db pg_dump -U mesrwl -d mes -Fc > "$FILE"
SIZE=$(du -h "$FILE" | cut -f1)
echo "Done: $FILE ($SIZE)"
