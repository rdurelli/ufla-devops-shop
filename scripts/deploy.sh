#!/usr/bin/env bash
set -euo pipefail

APP_USER="ufla-shop"
APP_DIR="/opt/ufla-shop"
ENV_FILE="/etc/ufla-shop.env"

echo "==> Instalando dependencias do sistema..."
apt update
apt install -y python3-venv postgresql redis-server nginx openssl

echo "==> Criando usuario da aplicacao..."
if ! id "${APP_USER}" >/dev/null 2>&1; then
    useradd --system --create-home --shell /usr/sbin/nologin "${APP_USER}"
fi

echo "==> Copiando aplicacao..."
mkdir -p "${APP_DIR}"

rsync -a \
    --exclude ".git" \
    --exclude ".venv" \
    --exclude "__pycache__" \
    ./ "${APP_DIR}/"

chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

echo "==> Criando ambiente virtual..."
if [ ! -d "${APP_DIR}/.venv" ]; then
    sudo -u "${APP_USER}" python3 -m venv "${APP_DIR}/.venv"
fi

echo "==> Instalando dependencias Python..."
sudo -u "${APP_USER}" "${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

echo "==> Configurando variaveis de ambiente..."
if [ ! -f "${ENV_FILE}" ]; then
    cat > "${ENV_FILE}" <<'EOF'
DATABASE_URL=postgresql://loja:123@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
EOF

    chmod 600 "${ENV_FILE}"
fi

echo "==> Instalando arquivos do systemd..."
cp "${APP_DIR}/systemd/ufla-shop.service" /etc/systemd/system/
cp "${APP_DIR}/systemd/ufla-shop-backup.service" /etc/systemd/system/
cp "${APP_DIR}/systemd/ufla-shop-backup.timer" /etc/systemd/system/

echo "==> Configurando Nginx..."
cp "${APP_DIR}/nginx/loja.conf" /etc/nginx/sites-available/loja.conf
ln -sf /etc/nginx/sites-available/loja.conf /etc/nginx/sites-enabled/loja.conf
rm -f /etc/nginx/sites-enabled/default

echo "==> Gerando certificado TLS..."
mkdir -p /etc/nginx/ssl

if [ ! -f /etc/nginx/ssl/loja.crt ]; then
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/loja.key \
        -out /etc/nginx/ssl/loja.crt \
        -subj "/CN=localhost"
fi

echo "==> Recarregando systemd..."
systemctl daemon-reload

systemctl enable ufla-shop.service
systemctl restart ufla-shop.service

systemctl enable --now ufla-shop-backup.timer

echo "==> Reiniciando Nginx..."
nginx -t
systemctl restart nginx

echo "==> Healthcheck..."
for i in {1..10}; do
    if curl -fsS http://localhost:8000/ready >/dev/null; then
        echo "Aplicacao pronta!"
        exit 0
    fi

    sleep 1
done

echo "Aplicacao nao respondeu ao healthcheck." >&2
exit 1