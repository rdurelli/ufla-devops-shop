#!/usr/bin/env bash
# deploy.sh -- instala a loja numa maquina limpa e nao quebra se rodar de novo.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "rode com sudo: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="/opt/ufla-shop"
ENV_FILE="/etc/ufla-shop.env"
ENV_EXAMPLE="/etc/ufla-shop.env.example"

if [ ! -f "$REPO_DIR/requirements.txt" ]; then
    echo "nao achei requirements.txt em $REPO_DIR -- rode a partir do clone do repositorio" >&2
    exit 1
fi

echo "== pacotes =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip \
    postgresql postgresql-client \
    redis-server nginx openssl rsync curl ca-certificates

echo "== servicos de banco e cache =="
systemctl enable --now postgresql
systemctl enable --now redis-server

# Espera o postgres aceitar conexao local.
for _ in $(seq 1 15); do
    if sudo -u postgres psql -c 'SELECT 1' >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo "== arquivo de ambiente =="
install -m 0644 "$REPO_DIR/etc/ufla-shop.env.example" "$ENV_EXAMPLE"
if [ ! -f "$ENV_FILE" ]; then
    install -m 0640 "$ENV_EXAMPLE" "$ENV_FILE"
    echo "criei $ENV_FILE a partir do example -- troque a senha se quiser"
fi

# shellcheck disable=SC1090
set -a
# shellcheck disable=SC1091
source "$ENV_FILE"
set +a
: "${DATABASE_URL:?DATABASE_URL ausente em $ENV_FILE}"
: "${REDIS_URL:?REDIS_URL ausente em $ENV_FILE}"

url="${DATABASE_URL#postgresql://}"
url="${url#postgres://}"
db_user="${url%%:*}"
rest="${url#*:}"
db_pass="${rest%%@*}"
rest="${rest#*@}"
db_name="${rest#*/}"
db_name="${db_name%%\?*}"
db_name="${db_name%%:*}"

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_user}'" | grep -q 1; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE USER ${db_user} WITH PASSWORD '${db_pass}';"
fi
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" | grep -q 1; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${db_name} OWNER ${db_user};"
fi

echo "== usuario de sistema =="
id ufla-shop &>/dev/null || useradd --system --home-dir "$APP_DIR" --shell /usr/sbin/nologin ufla-shop
chgrp ufla-shop "$ENV_FILE"
chmod 640 "$ENV_FILE"

echo "== codigo em $APP_DIR =="
mkdir -p "$APP_DIR"
rsync -a --delete \
    --exclude '.git/' \
    --exclude '.venv/' \
    --exclude 'dados/' \
    --exclude '__pycache__/' \
    --exclude '.pytest_cache/' \
    --exclude '.coverage' \
    "$REPO_DIR/" "$APP_DIR/"

if [ ! -x "$APP_DIR/.venv/bin/python" ]; then
    python3 -m venv "$APP_DIR/.venv"
fi
"$APP_DIR/.venv/bin/pip" install -q --upgrade pip
"$APP_DIR/.venv/bin/pip" install -q -r "$APP_DIR/requirements.txt"
chown -R ufla-shop:ufla-shop "$APP_DIR"

echo "== diretorio de backup =="
install -d -o ufla-shop -g ufla-shop -m 0750 /var/backups/ufla-shop

echo "== certificado tls =="
install -d -m 0755 /etc/ssl/ufla-shop
if [ ! -f /etc/ssl/ufla-shop/loja.pem ] || [ ! -f /etc/ssl/ufla-shop/loja.key ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/ufla-shop/loja.key \
        -out /etc/ssl/ufla-shop/loja.pem \
        -subj "/CN=localhost" >/dev/null 2>&1
    chmod 640 /etc/ssl/ufla-shop/loja.key
    chmod 644 /etc/ssl/ufla-shop/loja.pem
fi

echo "== systemd =="
install -m 0644 "$REPO_DIR/systemd/ufla-shop.service" /etc/systemd/system/
install -m 0644 "$REPO_DIR/systemd/ufla-shop-backup.service" /etc/systemd/system/
install -m 0644 "$REPO_DIR/systemd/ufla-shop-backup.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable ufla-shop.service >/dev/null
systemctl enable ufla-shop-backup.timer >/dev/null
systemctl restart ufla-shop.service
systemctl start ufla-shop-backup.timer

echo "== nginx =="
install -m 0644 "$REPO_DIR/nginx/loja.conf" /etc/nginx/sites-available/loja.conf
ln -sfn /etc/nginx/sites-available/loja.conf /etc/nginx/sites-enabled/loja.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx >/dev/null
systemctl reload nginx

echo "== healthcheck /ready =="
ok=0
for i in $(seq 1 10); do
    if curl -sf -o /dev/null http://127.0.0.1:8000/ready; then
        echo "ready ok na tentativa $i"
        ok=1
        break
    fi
    sleep 1
done
if [ "$ok" -ne 1 ]; then
    echo "ready nao respondeu 200 em 10s -- journalctl -u ufla-shop -n 50" >&2
    exit 1
fi

echo "deploy ok"
