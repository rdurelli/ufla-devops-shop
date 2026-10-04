#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/ufla-shop"
TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
BACKUP_FILE="${BACKUP_DIR}/loja-${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

if [ -f /etc/ufla-shop.env ]; then
    set -a
    source /etc/ufla-shop.env 2>/dev/null || true
    set +a
fi

DB_URL="${DATABASE_URL:-postgresql://loja:troque-esta-senha@localhost:5432/loja}"

if ! pg_dump "${DB_URL}" | gzip > "${BACKUP_FILE}"; then
    sudo -u postgres pg_dump loja | gzip > "${BACKUP_FILE}"
fi

FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
logger -t backup "Ficheiro gerado: ${BACKUP_FILE} | Tamanho: ${FILE_SIZE}"

ls -1t "${BACKUP_DIR}"/loja-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
