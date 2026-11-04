#!/usr/bin/env bash
set -euo pipefail

echo "=== Iniciando deploy da ufla-devops-shop ==="

APP_DIR="/opt/ufla-shop"
SERVICE_USER="ufla-shop"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Instala ferramentas necessárias
sudo apt-get update
sudo apt-get install -y nginx rsync openssl curl python3-venv postgresql-client

# Cria usuário de serviço se não existir
if ! id "$SERVICE_USER" &>/dev/null; then
    sudo useradd --system --home-dir "$APP_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
fi

echo "Usuário de serviço verificado."

# Copia o código
sudo mkdir -p "$APP_DIR"
sudo rsync -a --delete \
    --exclude='.git' \
    --exclude='.venv' \
    --exclude='__pycache__' \
    "$REPO_DIR/" "$APP_DIR/"

# Cria ambiente virtual e instala dependências
sudo python3 -m venv "$APP_DIR/.venv"
sudo "$APP_DIR/.venv/bin/pip" install --upgrade pip
sudo "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"
sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"

echo "Código e dependências preparados."

# Cria modelo de configuração sem sobrescrever o arquivo real
sudo tee /etc/ufla-shop.env.example >/dev/null <<'EOF'
DATABASE_URL=postgresql://loja:SENHA_DO_BANCO@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
EOF
sudo chmod 644 /etc/ufla-shop.env.example

if [ ! -f /etc/ufla-shop.env ]; then
    echo "ERRO: /etc/ufla-shop.env não existe. Crie o arquivo com as credenciais antes do deploy."
    exit 1
fi

# Confere credenciais do backup
if ! sudo test -f /root/.pgpass; then
    echo "ERRO: /root/.pgpass não existe."
    exit 1
fi
sudo chmod 600 /root/.pgpass

# Instala unidades do systemd versionadas no projeto
sudo install -m 644 "$REPO_DIR/systemd/ufla-shop.service" /etc/systemd/system/ufla-shop.service
sudo install -m 644 "$REPO_DIR/systemd/ufla-shop-backup.service" /etc/systemd/system/ufla-shop-backup.service
sudo install -m 644 "$REPO_DIR/systemd/ufla-shop-backup.timer" /etc/systemd/system/ufla-shop-backup.timer

echo "Unidades do systemd instaladas."

# Instala configuração versionada do Nginx
sudo install -m 644 "$REPO_DIR/nginx/loja.conf" /etc/nginx/sites-available/ufla-shop

# Gera certificado autoassinado se ainda não existir
if [ ! -f /etc/ssl/certs/ufla-shop.crt ]; then
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/ufla-shop.key \
        -out /etc/ssl/certs/ufla-shop.crt \
        -subj "/CN=localhost"
    sudo chmod 600 /etc/ssl/private/ufla-shop.key
fi

# Ativa o site
sudo ln -sfn /etc/nginx/sites-available/ufla-shop /etc/nginx/sites-enabled/ufla-shop
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t

# Ativa dependências
sudo systemctl enable --now postgresql redis-server

# Recarrega e ativa serviços
sudo systemctl daemon-reload
sudo systemctl enable --now nginx
sudo systemctl enable ufla-shop.service
sudo systemctl enable --now ufla-shop-backup.timer

# Reinicia aplicação
sudo systemctl restart ufla-shop.service

# Aguarda aplicação ficar pronta
echo "Verificando a saúde da aplicação..."

for tentativa in {1..10}; do
    if curl -fsS http://localhost:8000/ready >/dev/null; then
        echo "Deploy concluído: aplicação pronta!"
        exit 0
    fi

    echo "Aguardando aplicação... tentativa $tentativa/10"
    sleep 1
done

echo "ERRO: aplicação não ficou pronta."
sudo systemctl status ufla-shop.service --no-pager
exit 1
