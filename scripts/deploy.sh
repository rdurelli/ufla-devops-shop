#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute com sudo: sudo $0" >&2
    exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO=/opt/ufla-shop
USUARIO=ufla-shop

echo "==> 1/7 Pacotes"
apt-get update -q
apt-get install -y -q python3-venv postgresql redis-server nginx openssl curl

echo "==> 2/7 Usuario de sistema"
id "$USUARIO" &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin "$USUARIO"

echo "==> 3/7 Codigo e dependencias em $DESTINO"
mkdir -p "$DESTINO/scripts"
cp -r "$REPO/app" "$REPO/static" "$REPO/requirements.txt" "$DESTINO/"
cp "$REPO/scripts/backup.sh" "$DESTINO/scripts/backup.sh"
chmod 755 "$DESTINO/scripts/backup.sh"
[ -d "$DESTINO/.venv" ] || python3 -m venv "$DESTINO/.venv"
"$DESTINO/.venv/bin/pip" install -q -r "$DESTINO/requirements.txt"

echo "==> 4/7 Arquivo de ambiente (segredos)"
cp "$REPO/systemd/ufla-shop.env.example" /etc/ufla-shop.env.example
if [ ! -f /etc/ufla-shop.env ]; then
    cp /etc/ufla-shop.env.example /etc/ufla-shop.env
    chmod 600 /etc/ufla-shop.env
fi
if grep -q TROQUE_A_SENHA /etc/ufla-shop.env; then
    echo "Edite /etc/ufla-shop.env com a senha real do banco e rode o deploy de novo." >&2
    exit 1
fi

echo "==> 5/7 Pasta de backup"
install -d -o "$USUARIO" -g "$USUARIO" -m 750 /var/backups/ufla-shop

echo "==> 6/7 Units do systemd"
cp "$REPO"/systemd/*.service "$REPO"/systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable ufla-shop.service ufla-shop-backup.timer
systemctl restart ufla-shop.service
systemctl start ufla-shop-backup.timer

echo "==> 7/7 Nginx com TLS"
mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/loja.pem ]; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/loja.key -out /etc/nginx/ssl/loja.pem \
        -subj "/CN=localhost"
fi
cp "$REPO/nginx/loja.conf" /etc/nginx/sites-available/loja.conf
ln -sf /etc/nginx/sites-available/loja.conf /etc/nginx/sites-enabled/loja.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "==> Healthcheck em http://localhost:8000/ready"
for tentativa in $(seq 1 10); do
    if curl -fs http://localhost:8000/ready > /dev/null; then
        echo "OK: aplicacao no ar (tentativa $tentativa)"
        exit 0
    fi
    sleep 1
done
echo "FALHA: /ready nao respondeu 200 em 10 tentativas" >&2
echo "Veja: journalctl -u ufla-shop -n 50" >&2
exit 1
