#!/usr/bin/env bash
#
# backup.sh --- dump diario do banco `loja`, com rotacao.
#
#   ./scripts/backup.sh
#
# Roda como o usuario ufla-shop, disparado por ufla-shop-backup.timer as 3h.
# Tambem pode ser executado a mao, para provar a rotacao.
#
#   1. pg_dump do banco loja -> /var/backups/ufla-shop/loja-AAAA-MM-DD-HHMM.sql.gz
#   2. mantem os 7 dumps mais recentes e apaga o resto
#   3. sai com codigo diferente de zero se o pg_dump falhar
#   4. registra no journal o arquivo gerado e o tamanho

set -euo pipefail

DESTINO="${BACKUP_DIR:-/var/backups/ufla-shop}"
MANTER="${BACKUP_MANTER:-7}"
ARQUIVO="$DESTINO/loja-$(date +%Y-%m-%d-%H%M).sql.gz"

# O pg_dump nao recebe a senha em argumento nenhum. A credencial vem do
# .pgpass do usuario, apontado por PGPASSFILE --- criado pelo deploy.sh.
export PGPASSFILE="${PGPASSFILE:-/opt/ufla-shop/.pgpass}"

# A URL completa vem do EnvironmentFile da unit. O fallback existe para rodar
# o script a mao, fora do systemd.
DATABASE_URL="${DATABASE_URL:-postgresql://loja@localhost:5432/loja}"

# Repassa a URL como variaveis PG* em vez de --dbname. O motivo e o `ps`:
# um --dbname com a URL completa mostraria a senha para qualquer usuario da
# maquina. Como o .pgpass ja tem a credencial, aqui basta host/porta/usuario.
if [[ "$DATABASE_URL" =~ ^postgresql://([^:@/]+)(:[^@/]*)?@([^:/]+):([0-9]+)/(.+)$ ]]; then
  export PGUSER="${BASH_REMATCH[1]}"
  export PGHOST="${BASH_REMATCH[3]}"
  export PGPORT="${BASH_REMATCH[4]}"
  export PGDATABASE="${BASH_REMATCH[5]}"
else
  echo "backup.sh: DATABASE_URL em formato inesperado" >&2
  exit 1
fi

logger -t backup "iniciando dump do banco ${PGDATABASE}"

mkdir -p "$DESTINO"

# O `set -o pipefail` no topo e o que faz o gzip nao engolir a falha do
# pg_dump: sem ele, o status do pipeline seria o do gzip (sempre 0) e o
# script terminaria "com sucesso" deixando um dump truncado no disco.
pg_dump --no-owner --no-privileges | gzip -9 > "$ARQUIVO"

TAMANHO="$(du -h "$ARQUIVO" | cut -f1)"
logger -t backup "dump gerado: $ARQUIVO ($TAMANHO)"

# ------------------------------------------------------------------ rotacao
# O nome termina em AAAA-MM-DD-HHMM, entao a ordem alfabetica e a cronologica.
# `tail -n +$((MANTER + 1))` pula os MANTER mais novos e devolve os antigos.
mapfile -t ANTIGOS < <(
  find "$DESTINO" -maxdepth 1 -name 'loja-*.sql.gz' -printf '%f\n' | sort -r | tail -n +$((MANTER + 1))
)

for velho in "${ANTIGOS[@]:-}"; do
  [[ -n "$velho" ]] || continue
  rm -f "$DESTINO/$velho"
  logger -t backup "dump antigo removido: $velho"
done

RETIDOS="$(find "$DESTINO" -maxdepth 1 -name 'loja-*.sql.gz' | wc -l)"
logger -t backup "backup concluido: ${RETIDOS} dumps retidos"
