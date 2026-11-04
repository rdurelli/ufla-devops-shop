#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/ufla-shop"
DB_NAME="loja"
DB_USER="loja"
TIMESTAMP="$(date +%Y-%m-%d-%H%M)"
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}-${TIMESTAMP}.sql.gz"

# Cria o diretório de backups
mkdir -p "$BACKUP_DIR"

# Realiza o backup e interrompe em caso de erro
if pg_dump -h localhost -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"; then
    echo "Backup criado: $BACKUP_FILE"
else
    echo "ERRO: falha ao criar backup do banco $DB_NAME." >&2
    rm -f "$BACKUP_FILE"
    logger -t backup "ERRO ao criar backup do banco $DB_NAME"
    exit 1
fi

# Mantém somente os 7 backups mais recentes
mapfile -t BACKUPS < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${DB_NAME}-*.sql.gz" | sort -r)

if [ "${#BACKUPS[@]}" -gt 7 ]; then
    for arquivo in "${BACKUPS[@]:7}"; do
        rm -f "$arquivo"
    done
fi

# Registra o resultado no log do sistema
TAMANHO="$(du -h "$BACKUP_FILE" | cut -f1)"
logger -t backup "Backup concluído: $BACKUP_FILE (tamanho: $TAMANHO)"

echo "Backup concluído com sucesso."
echo "Arquivo: $BACKUP_FILE"
echo "Tamanho: $TAMANHO"
