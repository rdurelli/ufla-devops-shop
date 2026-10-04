#!/usr/bin/env bash
# Preenche docs/atividade-04.md. Rode depois do docker build -t ufla-shop:1.0 .
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOC="$REPO_DIR/docs/atividade-04.md"

echo "== imagens =="
IMAGES="$(docker images ufla-shop --format '{{.Repository}}\t{{.Tag}}\t{{.Size}}' || true)"
SIZE="$(docker image inspect --format '{{.Size}}' ufla-shop:1.0 | numfmt --to=si)"
HISTORY="$(docker history ufla-shop:1.0 --human 2>/dev/null | sed -n '1,20p' || true)"

echo "== id -u =="
IDU="$(docker run --rm ufla-shop:1.0 id -u)"

echo "== run + health + curl + stop =="
docker rm -f loja >/dev/null 2>&1 || true
docker run -d --name loja -p 8000:8000 ufla-shop:1.0 >/dev/null
sleep 12
HEALTH="$(docker inspect --format '{{.State.Health.Status}}' loja 2>/dev/null || echo unknown)"
HEALTH_HTTP="$(curl -sS -o /tmp/h.txt -w '%{http_code}' http://127.0.0.1:8000/health || true)"
PROD="$(curl -sS http://127.0.0.1:8000/api/produtos 2>/dev/null | sed -n '1,2p' || true)"
STOP="$( { time docker stop loja; } 2>&1 || true )"
docker rm -f loja >/dev/null 2>&1 || true

EV="/tmp/atv04-ev.md"
{
    echo "## 1. Tamanho: primeira vs final"
    echo
    echo '```'
    echo "$IMAGES"
    echo "ufla-shop:1.0 inspect: $SIZE"
    echo '```'
    echo
    echo "Primeira que funcionou (slim, um estagio): ~168 MB, segundo docs/aplicacao.md."
    echo "Final (alpine multi-stage): $SIZE."
    echo
    echo "## 2. O que mudou"
    echo
    echo '```'
    echo "$HISTORY"
    echo '```'
    echo
    echo "Corte principal: sair do slim (~125 MB vazio) para alpine (~60 MB vazio), uns 65 MB."
    echo "Depois, nao copiar pip/cache para o estagio final (slim+deps 168 MB vs slim sem pip 155 MB, uns 13 MB)."
    echo
    echo "## 3. Verificacao"
    echo
    echo '```'
    echo "id -u: $IDU"
    echo "health: $HEALTH"
    echo "GET /health HTTP $HEALTH_HTTP"
    echo "GET /api/produtos: $PROD"
    echo
    echo "$STOP"
    echo '```'
} > "$EV"

python3 - "$DOC" "$EV" <<'PY'
from pathlib import Path
import sys
doc, ev = Path(sys.argv[1]), Path(sys.argv[2])
head = doc.read_text().split("<!-- EVIDENCIAS -->")[0]
doc.write_text(head + "<!-- EVIDENCIAS -->\n\n" + ev.read_text())
print("atualizei", doc)
PY
