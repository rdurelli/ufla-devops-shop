#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DATABASE_URL:-}" ] && [ -f /etc/ufla-shop.env ]; then
    set -a
    source /etc/ufla-shop.env
    set +a
fi

BACKUP_DIR="/var/backups/ufla-shop"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
ARQUIVO="${BACKUP_DIR}/loja-${TIMESTAMP}.sql.gz"

if [ -f "$ARQUIVO" ]; then
    TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
    ARQUIVO="${BACKUP_DIR}/loja-${TIMESTAMP}.sql.gz"
fi

if ! pg_dump "$DATABASE_URL" | gzip > "$ARQUIVO"; then
    rm -f "$ARQUIVO"
    exit 1
fi

TAMANHO=$(du -h "$ARQUIVO" | cut -f1)
logger -t backup "Backup concluido: ${ARQUIVO} (tamanho: ${TAMANHO})"
echo "Backup gerado com sucesso: ${ARQUIVO} (${TAMANHO})"

ls -1t "${BACKUP_DIR}"/loja-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
