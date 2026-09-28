#!/usr/bin/env bash
set -euo pipefail

echo "==> [1/7] A verificar utilizador de sistema ufla-shop..."
id ufla-shop &>/dev/null || sudo useradd --system --home-dir /opt/ufla-shop --shell /usr/sbin/nologin ufla-shop

echo "==> [2/7] A preparar ficheiro de ambiente (/etc/ufla-shop.env)..."
if [ ! -f /etc/ufla-shop.env.example ]; then
    sudo tee /etc/ufla-shop.env.example > /dev/null << 'EOF'
DATABASE_URL=postgresql://loja:troque-esta-senha@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
EOF
fi

if [ ! -f /etc/ufla-shop.env ]; then
    sudo cp /etc/ufla-shop.env.example /etc/ufla-shop.env
    sudo chmod 640 /etc/ufla-shop.env
    sudo chown root:ufla-shop /etc/ufla-shop.env
fi

echo "==> [3/7] A preparar diretorio de backups (/var/backups/ufla-shop)..."
sudo mkdir -p /var/backups/ufla-shop
sudo chown -R ufla-shop:ufla-shop /var/backups/ufla-shop

echo "==> [4/7] A sincronizar codigo para /opt/ufla-shop e instalar dependencias..."
sudo mkdir -p /opt/ufla-shop
sudo cp -r app static requirements.txt /opt/ufla-shop/
sudo mkdir -p /opt/ufla-shop/scripts
if [ -f scripts/backup.sh ]; then
    sudo cp scripts/backup.sh /opt/ufla-shop/scripts/
    sudo chmod +x /opt/ufla-shop/scripts/backup.sh
fi

sudo python3 -m venv /opt/ufla-shop/.venv
sudo /opt/ufla-shop/.venv/bin/pip install --quiet --upgrade pip
sudo /opt/ufla-shop/.venv/bin/pip install --quiet -r /opt/ufla-shop/requirements.txt
sudo chown -R ufla-shop:ufla-shop /opt/ufla-shop

echo "==> [5/7] A configurar certificado TLS e Nginx..."
sudo mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/loja.crt ] || [ ! -f /etc/nginx/ssl/loja.key ]; then
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/loja.key \
        -out /etc/nginx/ssl/loja.crt \
        -subj "/C=BR/ST=MG/L=Lavras/O=UFLA/CN=localhost" 2>/dev/null
fi

if [ -f nginx/loja.conf ]; then
    sudo cp nginx/loja.conf /etc/nginx/sites-available/loja.conf
    sudo ln -sf /etc/nginx/sites-available/loja.conf /etc/nginx/sites-enabled/loja.conf
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t
    sudo systemctl enable nginx
    sudo systemctl restart nginx
fi

echo "==> [6/7] A instalar e iniciar units do systemd..."
sudo cp systemd/ufla-shop.service /etc/systemd/system/
sudo cp systemd/ufla-shop-backup.service /etc/systemd/system/
sudo cp systemd/ufla-shop-backup.timer /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable ufla-shop.service
sudo systemctl restart ufla-shop.service
sudo systemctl enable --now ufla-shop-backup.timer

echo "==> [7/7] A executar healthcheck em http://localhost:8000/ready..."
for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ready || true)
    if [ "$STATUS" = "200" ]; then
        echo "Healthcheck OK (HTTP 200) na tentativa $i!"
        exit 0
    fi
    echo "Tentativa $i/10: status $STATUS. A aguardar 1s..."
    sleep 1
done

echo "ERRO: A aplicacao nao respondeu 200 em /ready apos 10 tentativas."
exit 1