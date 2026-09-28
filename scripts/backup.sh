#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/ufla-shop"
DATA="$(date +%Y-%m-%d-%H%M%S)"
ARQUIVO="${BACKUP_DIR}/loja-${DATA}.sql.gz"

source /etc/ufla-shop.env

mkdir -p "${BACKUP_DIR}"

pg_dump "${DATABASE_URL}" | gzip > "${ARQUIVO}"

ls -1t "${BACKUP_DIR}"/loja-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm --

TAMANHO="$(du -h "${ARQUIVO}" | cut -f1)"

logger -t backup "Backup gerado: ${ARQUIVO} (${TAMANHO})"