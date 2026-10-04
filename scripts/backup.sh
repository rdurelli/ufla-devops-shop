#!/usr/bin/env bash
# backup.sh -- dump do banco loja com rotacao de 7 arquivos.
# Precisa de DATABASE_URL (systemd carrega via EnvironmentFile).
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL nao definida -- rode via systemd ou exporte a variavel}"

DESTINO="/var/backups/ufla-shop"
mkdir -p "$DESTINO"

ARQUIVO="$DESTINO/loja-$(date +%Y-%m-%d-%H%M).sql.gz"

pg_dump "$DATABASE_URL" | gzip > "$ARQUIVO"

TAMANHO="$(wc -c < "$ARQUIVO" | tr -d ' ')"
logger -t backup "gerado $ARQUIVO (${TAMANHO} bytes)"
printf 'backup ok: %s (%s bytes)\n' "$ARQUIVO" "$TAMANHO"

# Mantem os 7 mais recentes. tail -n +8 = do oitavo em diante.
ls -1t "$DESTINO"/loja-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
