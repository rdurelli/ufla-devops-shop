#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/ufla-shop"
TIMESTAMP="$(date '+%Y-%m-%d-%H%M')"
BACKUP_FILE="${BACKUP_DIR}/loja-${TIMESTAMP}.sql.gz"

umask 077
mkdir -p "$BACKUP_DIR"

# Se o pg_dump ou o gzip falhar, o pipefail aciona esta limpeza.
trap 'rm -f -- "$BACKUP_FILE"' ERR

pg_dump --dbname="$DATABASE_URL" | gzip > "$BACKUP_FILE"

gzip -t "$BACKUP_FILE"
trap - ERR

mapfile -t BACKUPS < <(
    find "$BACKUP_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'loja-*.sql.gz' \
        -printf '%T@ %p\n' |
        sort -rn |
        cut -d' ' -f2-
)

if (( ${#BACKUPS[@]} > 7 )); then
    printf '%s\0' "${BACKUPS[@]:7}" | xargs -0r rm --
fi

BACKUP_SIZE="$(stat --format='%s bytes' "$BACKUP_FILE")"
logger -t backup "Backup gerado: $BACKUP_FILE ($BACKUP_SIZE)"
