#!/usr/bin/env bash
set -euo pipefail

readonly BACKUP_DIR="/var/backups/ufla-shop"

: "${DATABASE_URL:?DATABASE_URL não está definido no ambiente}"
[[ -d "${BACKUP_DIR}" && -w "${BACKUP_DIR}" ]] || {
    printf 'Diretório de backup ausente ou sem permissão: %s\n' "${BACKUP_DIR}" >&2
    exit 1
}

umask 077

timestamp="$(date '+%F-%H%M')"
backup_file="${BACKUP_DIR}/loja-${timestamp}.sql.gz"

# O nome exigido tem precisão de minuto. Aguarde o minuto seguinte para não
# sobrescrever um dump se o backup for executado duas vezes no mesmo minuto.
while [[ -e "${backup_file}" ]]; do
    sleep 1
    timestamp="$(date '+%F-%H%M')"
    backup_file="${BACKUP_DIR}/loja-${timestamp}.sql.gz"
done

tmp_file=""
cleanup() {
    if [[ -n "${tmp_file}" ]]; then
        rm -f -- "${tmp_file}"
    fi
}
trap cleanup EXIT

tmp_file="$(mktemp "${BACKUP_DIR}/.loja-${timestamp}.XXXXXX.tmp")"
pg_dump --dbname="${DATABASE_URL}" --no-owner --no-privileges | gzip -c > "${tmp_file}"
mv -- "${tmp_file}" "${backup_file}"
tmp_file=""

mapfile -t backups < <(
    find "${BACKUP_DIR}" -maxdepth 1 -type f -name 'loja-*.sql.gz' -printf '%f\n' |
        sort -r
)
for old_backup in "${backups[@]:7}"; do
    rm -f -- "${BACKUP_DIR}/${old_backup}"
done

size="$(du -h -- "${backup_file}" | cut -f1)"
logger -t backup "Arquivo gerado: ${backup_file}; tamanho: ${size}"
printf 'Backup gerado: %s (%s)\n' "${backup_file}" "${size}"
