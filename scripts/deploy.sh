#!/usr/bin/env bash
set -euo pipefail

APP_USER="ufla-shop"
APP_DIR="/opt/ufla-shop"
ENV_FILE="/etc/ufla-shop.env"
ENV_EXAMPLE="/etc/ufla-shop.env.example"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if (( EUID != 0 )); then
    echo "ERRO: execute este script com sudo."
    exit 1
fi

echo "==> Iniciando deploy do UFLa Shop"

echo "==> Verificando usuario da aplicacao"

if ! id "$APP_USER" >/dev/null 2>&1; then
    useradd \
        --system \
        --user-group \
        --home-dir "$APP_DIR" \
        --shell /usr/sbin/nologin \
        "$APP_USER"
    echo "Usuario $APP_USER criado"
else
    echo "Usuario $APP_USER ja existe"
fi

echo "==> Instalando dependencias do sistema"

PACOTES=()

command -v logger >/dev/null 2>&1 || PACOTES+=(bsdutils)
command -v curl >/dev/null 2>&1 || PACOTES+=(curl)
command -v gzip >/dev/null 2>&1 || PACOTES+=(gzip)
command -v nginx >/dev/null 2>&1 || PACOTES+=(nginx)
command -v openssl >/dev/null 2>&1 || PACOTES+=(openssl)
command -v pg_dump >/dev/null 2>&1 || PACOTES+=(postgresql-client)
command -v rsync >/dev/null 2>&1 || PACOTES+=(rsync)

if ! command -v python3 >/dev/null 2>&1; then
    PACOTES+=(python3 python3-venv)
elif ! python3 -m venv --help >/dev/null 2>&1; then
    PACOTES+=(python3-venv)
fi

if (( ${#PACOTES[@]} > 0 )); then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACOTES[@]}"
else
    echo "Dependencias ja instaladas"
fi

echo "==> Verificando configuracao"

if [[ ! -f "$PROJECT_DIR/.env.example" ]]; then
    echo "ERRO: .env.example nao encontrado no projeto."
    exit 1
fi

# Mantem no /etc um modelo sem senha real e nao sobrescreve a configuracao.
install -m 644 "$PROJECT_DIR/.env.example" "$ENV_EXAMPLE"

if [[ ! -f "$ENV_FILE" ]]; then
    install -m 600 "$ENV_EXAMPLE" "$ENV_FILE"
    echo "Arquivo $ENV_FILE criado"
    echo "Configure a senha do banco nesse arquivo e execute o deploy novamente."
    exit 1
fi

chmod 600 "$ENV_FILE"

echo "==> Sincronizando aplicacao em $APP_DIR"

mkdir -p "$APP_DIR"

rsync -a --delete \
    --exclude '.git/' \
    --exclude '.venv/' \
    --exclude '__pycache__/' \
    "$PROJECT_DIR/" "$APP_DIR/"

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo "==> Configurando ambiente Python"

if [[ ! -d "$APP_DIR/.venv" ]]; then
    python3 -m venv "$APP_DIR/.venv"
fi

"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

chown -R "$APP_USER:$APP_USER" "$APP_DIR"
chmod 755 "$APP_DIR/scripts/deploy.sh" "$APP_DIR/scripts/backup.sh"

echo "==> Instalando units do systemd"

install -m 644 \
    "$APP_DIR/systemd/ufla-shop.service" \
    /etc/systemd/system/ufla-shop.service

install -m 644 \
    "$APP_DIR/systemd/ufla-shop-backup.service" \
    /etc/systemd/system/ufla-shop-backup.service

install -m 644 \
    "$APP_DIR/systemd/ufla-shop-backup.timer" \
    /etc/systemd/system/ufla-shop-backup.timer

systemctl daemon-reload
systemctl enable ufla-shop.service ufla-shop-backup.timer
systemctl restart ufla-shop.service
systemctl start ufla-shop-backup.timer

echo "==> Configurando Nginx e HTTPS"

if [[ ! -f /etc/ssl/certs/ufla-shop.crt ||
      ! -f /etc/ssl/private/ufla-shop.key ]]; then
    openssl req \
        -x509 \
        -nodes \
        -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/ssl/private/ufla-shop.key \
        -out /etc/ssl/certs/ufla-shop.crt \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
fi

chmod 600 /etc/ssl/private/ufla-shop.key

install -d /etc/nginx/sites-available /etc/nginx/sites-enabled
install -m 644 \
    "$APP_DIR/nginx/loja.conf" \
    /etc/nginx/sites-available/loja.conf
ln -sfn \
    /etc/nginx/sites-available/loja.conf \
    /etc/nginx/sites-enabled/loja.conf

rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx.service
systemctl restart nginx

echo "==> Aguardando aplicacao responder em /ready"

for tentativa in {1..10}; do
    HTTP_CODE="$(
        curl \
            --silent \
            --output /dev/null \
            --write-out '%{http_code}' \
            http://localhost:8000/ready \
        || true
    )"

    if [[ "$HTTP_CODE" == "200" ]]; then
        echo "Healthcheck OK: HTTP 200"
        echo "==> Deploy concluido com sucesso."
        exit 0
    fi

    echo "Tentativa $tentativa/10: HTTP ${HTTP_CODE:-sem resposta}"
    if (( tentativa < 10 )); then
        sleep 1
    fi
done

echo "ERRO: aplicacao nao respondeu HTTP 200 em /ready."
systemctl status ufla-shop.service --no-pager || true
exit 1
