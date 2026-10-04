#!/usr/bin/env bash
# Preenche docs/atividade-03.md com as evidencias. Rode DEPOIS do deploy, com sudo.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "rode com sudo: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOC="$REPO_DIR/docs/atividade-03.md"

echo "== kill -9 =="
# pidof pode devolver varios PIDs
# shellcheck disable=SC2046
kill -9 $(pidof uvicorn) 2>/dev/null || true
sleep 5
STATUS="$(systemctl status ufla-shop --no-pager || true)"

echo "== curl =="
CURL_HTTPS="$(curl -kI https://localhost 2>&1 || true)"
CURL_HTTP="$(curl -I http://localhost 2>&1 || true)"

echo "== backup 3x =="
systemctl start ufla-shop-backup.service
sleep 1
systemctl start ufla-shop-backup.service
sleep 1
systemctl start ufla-shop-backup.service
LS_BACKUP="$(ls -la /var/backups/ufla-shop)"

echo "== deploy duas vezes =="
DEPLOY1="$(bash "$REPO_DIR/scripts/deploy.sh" | tail -n 25)"
DEPLOY2="$(bash "$REPO_DIR/scripts/deploy.sh" | tail -n 25)"
TIMERS="$(systemctl list-timers ufla-shop-backup.timer --no-pager || true)"

EV="/tmp/atv03-ev.md"
{
    echo "## (b) Restart depois do kill -9"
    echo
    echo '```'
    echo "$STATUS"
    echo '```'
    echo
    echo "## (c) curl HTTPS e HTTP"
    echo
    echo '```'
    echo "$CURL_HTTPS"
    echo '```'
    echo
    echo '```'
    echo "$CURL_HTTP"
    echo '```'
    echo
    echo "## (d) Backups depois de rodar 3 vezes"
    echo
    echo '```'
    echo "$LS_BACKUP"
    echo '```'
    echo
    echo "## (e) Idempotencia: final das duas execucoes seguidas"
    echo
    echo "Primeira:"
    echo
    echo '```'
    echo "$DEPLOY1"
    echo '```'
    echo
    echo "Segunda:"
    echo
    echo '```'
    echo "$DEPLOY2"
    echo '```'
    echo
    echo "## Timer"
    echo
    echo '```'
    echo "$TIMERS"
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
