#!/usr/bin/env bash
#
# backup.sh — dump do banco "loja", com rotação (mantém os 7 mais recentes).
# Executado via ufla-shop-backup.service (oneshot), disparado pelo
# ufla-shop-backup.timer.

set -euo pipefail

# --------------------------------------------------------------------------
# Configuração
# --------------------------------------------------------------------------
BACKUP_DIR="/var/backups/ufla-shop"
KEEP="7"
DB_NAME="loja"
DB_USER="${DB_USER:-loja}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
TIMESTAMP="$(date +%Y-%m-%d-%H%M)"
DUMP_FILE="${BACKUP_DIR}/${DB_NAME}-${TIMESTAMP}.sql.gz"

log() {
    echo "[backup] $*"
}

# --------------------------------------------------------------------------
# 1. Dump do banco
# --------------------------------------------------------------------------
mkdir -p "${BACKUP_DIR}"

log "Iniciando dump de ${DB_NAME} para ${DUMP_FILE}..."

# pipefail garante que uma falha no pg_dump propague o exit code,
# mesmo passando pelo gzip.
pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${DB_NAME}" | gzip > "${DUMP_FILE}"

if [[ ! -s "${DUMP_FILE}" ]]; then
    echo "[backup] ERRO: ${DUMP_FILE} não foi gerado ou está vazio." >&2
    logger -t backup "FALHA: dump de ${DB_NAME} não gerou arquivo válido"
    exit 1
fi

DUMP_SIZE="$(du -h "${DUMP_FILE}" | cut -f1)"
log "Dump concluído: ${DUMP_FILE} (${DUMP_SIZE})"

# --------------------------------------------------------------------------
# 2. Rotação — mantém apenas os 7 dumps mais recentes
# --------------------------------------------------------------------------
log "Aplicando rotação (mantendo os ${KEEP} mais recentes)..."

mapfile -t OLD_DUMPS < <(ls -1t "${BACKUP_DIR}"/${DB_NAME}-*.sql.gz 2>/dev/null | tail -n +"$((KEEP + 1))")

if [[ "${#OLD_DUMPS[@]}" -gt 0 ]]; then
    for old in "${OLD_DUMPS[@]}"; do
        log "Removendo backup antigo: ${old}"
        rm -f -- "${old}"
    done
else
    log "Nenhum backup antigo para remover."
fi

# --------------------------------------------------------------------------
# 3. Log no journal
# --------------------------------------------------------------------------
logger -t backup "OK: gerado ${DUMP_FILE} (${DUMP_SIZE})"

log "Backup finalizado com sucesso."