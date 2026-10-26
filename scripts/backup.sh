#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=/etc/ufla-shop.env
BACKUP_DIR=/var/backups/ufla-shop
mkdir -p "$BACKUP_DIR"
# shellcheck disable=SC1090
source "$ENV_FILE"

arquivo="$BACKUP_DIR/loja-$(date +%Y-%m-%d-%H%M).sql.gz"
pg_dump "$DATABASE_URL" | gzip >"$arquivo"
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'loja-*.sql.gz' -printf '%T@ %p\n' \
    | sort -rn | tail -n +8 | cut -d' ' -f2- | xargs -r rm -f --
logger -t backup "arquivo gerado: $arquivo tamanho: $(stat -c '%s' "$arquivo") bytes"