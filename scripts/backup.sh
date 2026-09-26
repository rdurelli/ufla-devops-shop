#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/ufla-shop"
mkdir -p "$BACKUP_DIR"

if [ -z "${DATABASE_URL:-}" ] && [ -f /etc/ufla-shop.env ]; then
    set -a
    source /etc/ufla-shop.env
    set +a
fi

DATE=$(date +"%Y-%m-%d-%H%M")
BACKUP_FILE="${BACKUP_DIR}/loja-${DATE}.sql.gz"

trap 'rm -f "$BACKUP_FILE"' ERR

pg_dump "${DATABASE_URL}" | gzip > "$BACKUP_FILE"

ls -1t "${BACKUP_DIR}"/loja-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
logger -t backup "Backup gerado com sucesso: $BACKUP_FILE (Tamanho: $SIZE)"
