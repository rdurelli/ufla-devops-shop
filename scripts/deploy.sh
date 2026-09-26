#!/usr/bin/env bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Erro: Este script deve ser executado como root (ex: sudo ./scripts/deploy.sh)" >&2
    exit 1
fi

echo "!-- Iniciando Deploy --!"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_DIR="/opt/ufla-shop"
APP_USER=${1:-ufla-shop}
ENV_EXAMPLE="/etc/ufla-shop.env.example"
ENV_FILE="/etc/ufla-shop.env"

echo "1. Verificando usuário do sistema ($APP_USER)..."
if ! id "$APP_USER" &>/dev/null; then
    echo "Criando usuário de sistema: $APP_USER"
    useradd --system --no-create-home --shell /bin/false "$APP_USER"
else
    echo "Usuário $APP_USER já existe. Ignorando."
fi

echo "Copiando arquivos da aplicação para $APP_DIR..."
mkdir -p "$APP_DIR"
cp -r "$REPO_DIR/app" "$REPO_DIR/static" "$REPO_DIR/requirements.txt" "$APP_DIR/"

mkdir -p "$APP_DIR/scripts"
cp "$REPO_DIR/scripts/backup.sh" "$APP_DIR/scripts/backup.sh"
chmod +x "$APP_DIR/scripts/backup.sh"

mkdir -p /var/backups/ufla-shop
echo "Ajustando permissões dos arquivos em $APP_DIR..."
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

echo "Configurando venv Python e instalando dependências..."
if [ ! -d "$APP_DIR/.venv" ]; then
    sudo -u "$APP_USER" python3 -m venv "$APP_DIR/.venv"
fi
sudo -u "$APP_USER" "$APP_DIR/.venv/bin/pip" install --quiet --upgrade pip
sudo -u "$APP_USER" "$APP_DIR/.venv/bin/pip" install --quiet -r "$APP_DIR/requirements.txt"

echo "Configurando variáveis de ambiente..."
if [ ! -f "$ENV_EXAMPLE" ]; then
    echo "Criando $ENV_EXAMPLE..."
    cat <<EOF > "$ENV_EXAMPLE"
DATABASE_URL=postgresql://loja:troque-esta-senha@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
EOF
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Criando $ENV_FILE a partir do exemplo..."
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    chown root:"$APP_USER" "$ENV_FILE"
    chmod 640 "$ENV_FILE"
else
    echo "Arquivo $ENV_FILE já existe. Preservando segredos."
fi

echo "Configurando certificados TLS..."
mkdir -p /etc/ssl/certs /etc/ssl/private
if [ ! -f /etc/ssl/certs/ufla-shop.crt ] || [ ! -f /etc/ssl/private/ufla-shop.key ]; then
    echo "Gerando certificado TLS autoassinado..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/ufla-shop.key \
        -out /etc/ssl/certs/ufla-shop.crt \
        -subj "/CN=localhost"
    chmod 600 /etc/ssl/private/ufla-shop.key
else
    echo "Certificados TLS já existem. Preservando."
fi

echo "Configurando Nginx..."
if [ -d /etc/nginx/sites-available ] && [ -d /etc/nginx/sites-enabled ]; then
    # Debian / Ubuntu
    rm -f /etc/nginx/sites-enabled/default
    cp "$REPO_DIR/nginx/loja.conf" /etc/nginx/sites-available/loja.conf
    ln -sf /etc/nginx/sites-available/loja.conf /etc/nginx/sites-enabled/loja.conf
else
    # Fedora / Arch Linux
    mkdir -p /etc/nginx/conf.d
    cp "$REPO_DIR/nginx/loja.conf" /etc/nginx/conf.d/loja.conf
fi

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "Instalando units do Systemd..."
cp "$REPO_DIR/systemd/ufla-shop.service" /etc/systemd/system/
cp "$REPO_DIR/systemd/ufla-shop-backup.service" /etc/systemd/system/
cp "$REPO_DIR/systemd/ufla-shop-backup.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable ufla-shop.service
systemctl restart ufla-shop.service
systemctl enable --now ufla-shop-backup.timer

echo "Executando Healthcheck ❤..."
RETRIES=10
RETRY_COUNT=0
URL="http://localhost:8000/ready"

while [ "$RETRY_COUNT" -lt "$RETRIES" ]; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || true)

    if [ "$HTTP_STATUS" = "200" ]; then
        echo "RES = 200 | OK! Aplicação pronta."
        exit 0
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Tentativa $RETRY_COUNT de $RETRIES falhou. Aguardando 1s..."
    sleep 1
done

echo "Falha no deploy: aplicação não respondeu 200 em $URL após $RETRIES tentativas."
exit 1
