#!/usr/bin/env bash
set -euo pipefail

DESTINO=/var/backups/ufla-shop
ARQUIVO="$DESTINO/loja-$(date +%Y-%m-%d-%H%M).sql.gz"

mkdir -p "$DESTINO"

if ! pg_dump "$DATABASE_URL" | gzip > "$ARQUIVO"; then
    rm -f "$ARQUIVO"
    logger -t backup "FALHA no backup do banco"
    exit 1
fi

ls -1t "$DESTINO"/loja-*.sql.gz | tail -n +8 | xargs -r rm -f

TAMANHO=$(du -h "$ARQUIVO" | cut -f1)
logger -t backup "backup gerado: $ARQUIVO ($TAMANHO)"
echo "backup gerado: $ARQUIVO ($TAMANHO)"
