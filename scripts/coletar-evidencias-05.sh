#!/usr/bin/env bash
# Preenche docs/atividade-05.md. Precisa de .env e da imagem ja puxavel/local.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOC="$REPO_DIR/docs/atividade-05.md"
cd "$REPO_DIR"

docker compose up -d --wait

PS1="$(docker compose ps)"
CURL_I="$(curl -sSI http://localhost | head -n 15)"
INFO="$(curl -sS http://localhost/api/info)"
POST="$(curl -sS -X POST http://localhost/api/produtos \
  -H 'Content-Type: application/json' \
  -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}')"

docker compose down
docker compose up -d --wait
BUSCA="$(curl -sS 'http://localhost/api/busca?q=persistencia')"
PS2="$(docker compose ps)"

EV="/tmp/atv05-ev.md"
{
    echo "## (a) docker compose ps"
    echo
    echo '```'
    echo "$PS1"
    echo '```'
    echo
    echo "## (b) Persistencia: POST, down, up, busca"
    echo
    echo '```'
    echo "curl -I:"
    echo "$CURL_I"
    echo
    echo "/api/info:"
    echo "$INFO"
    echo
    echo "POST /api/produtos:"
    echo "$POST"
    echo
    echo "depois do down + up, busca persistencia:"
    echo "$BUSCA"
    echo
    echo "ps final:"
    echo "$PS2"
    echo '```'
    echo
    echo "## (c) Imagem no GHCR"
    echo
    echo "ghcr.io/felipeoliveira456/ufla-shop:1.0.0"
    echo
} > "$EV"

python3 - "$DOC" "$EV" <<'PY'
from pathlib import Path
import sys
doc, ev = Path(sys.argv[1]), Path(sys.argv[2])
head = doc.read_text().split("<!-- EVIDENCIAS -->")[0]
doc.write_text(head + "<!-- EVIDENCIAS -->\n\n" + ev.read_text())
print("atualizei", doc)
PY
