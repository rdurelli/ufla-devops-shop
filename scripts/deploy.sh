#!/usr/bin/env bash
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR=/opt/ufla-shop
ENV_FILE=/etc/ufla-shop.env
ENV_EXAMPLE=/etc/ufla-shop.env.example
BACKUP_DIR=/var/backups/ufla-shop

dnf install -y python3 python3-pip postgresql-server redis nginx openssl curl gzip

if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
    postgresql-setup --initdb
fi
systemctl enable --now postgresql redis

id ufla-shop &>/dev/null || useradd --system --home-dir "$APP_DIR" --shell /sbin/nologin ufla-shop
install -d -o ufla-shop -g ufla-shop "$APP_DIR" "$BACKUP_DIR"
rsync -a --delete --exclude '.git' --exclude '.venv' --exclude '__pycache__' "$RAIZ/" "$APP_DIR/"
python3 -m venv "$APP_DIR/.venv"
"$APP_DIR/.venv/bin/pip" install --disable-pip-version-check -r "$APP_DIR/requirements.txt"
chown -R ufla-shop:ufla-shop "$APP_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
    if [[ ! -f "$ENV_EXAMPLE" ]]; then
        password="$(openssl rand -hex 24)"
        cat >"$ENV_EXAMPLE" <<EOF
DATABASE_URL=postgresql://loja:${password}@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
EOF
        chmod 600 "$ENV_EXAMPLE"
    fi
    install -o root -g root -m 600 "$ENV_EXAMPLE" "$ENV_FILE"
fi

# shellcheck disable=SC1090
source "$ENV_FILE"
db_password="${DATABASE_URL##*://loja:}"
db_password="${db_password%%@*}"
pg_hba=/var/lib/pgsql/data/pg_hba.conf
if ! grep -qx 'host all loja 127.0.0.1/32 scram-sha-256' "$pg_hba"; then
    sed -i '1ihost all loja 127.0.0.1/32 scram-sha-256' "$pg_hba"
fi
if ! grep -qx 'host all loja ::1/128 scram-sha-256' "$pg_hba"; then
    sed -i '1ihost all loja ::1/128 scram-sha-256' "$pg_hba"
fi
systemctl reload postgresql
sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'loja') THEN CREATE ROLE loja LOGIN; END IF; END \$\$;"
printf "ALTER ROLE loja PASSWORD '%s';\n" "$db_password" | sudo -u postgres psql -v ON_ERROR_STOP=1
if ! sudo -u postgres psql -Atqc "SELECT 1 FROM pg_database WHERE datname = 'loja'" | grep -qx 1; then
    sudo -u postgres createdb -O loja loja
fi
sudo -u postgres psql -d loja -v ON_ERROR_STOP=1 \
    -c "GRANT USAGE, CREATE ON SCHEMA public TO loja;" \
    -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO loja;" \
    -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO loja;"

install -d -m 755 /etc/systemd/system /etc/nginx/conf.d
install -m 644 "$RAIZ/systemd/ufla-shop.service" /etc/systemd/system/ufla-shop.service
install -m 644 "$RAIZ/systemd/ufla-shop-backup.service" /etc/systemd/system/ufla-shop-backup.service
install -m 644 "$RAIZ/systemd/ufla-shop-backup.timer" /etc/systemd/system/ufla-shop-backup.timer

if [[ ! -f /etc/pki/tls/certs/ufla-shop.pem || ! -f /etc/pki/tls/private/ufla-shop.key ]]; then
    install -d -m 755 /etc/pki/tls/certs /etc/pki/tls/private
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/pki/tls/private/ufla-shop.key \
        -out /etc/pki/tls/certs/ufla-shop.pem \
        -subj '/CN=localhost' >/dev/null 2>&1
    chmod 600 /etc/pki/tls/private/ufla-shop.key
fi
install -m 644 "$RAIZ/nginx/loja.conf" /etc/nginx/conf.d/loja.conf
install -m 644 "$RAIZ/nginx/nginx.conf" /etc/nginx/nginx.conf
rm -f /etc/nginx/conf.d/default.conf
if command -v setsebool &>/dev/null; then
    setsebool -P httpd_can_network_connect 1
fi

systemctl daemon-reload
systemctl enable --now ufla-shop
systemctl enable --now ufla-shop-backup.timer
nginx -t
systemctl enable --now nginx
systemctl reload nginx

for tentativa in {1..10}; do
    if curl --fail --silent --show-error http://127.0.0.1:8000/ready >/dev/null; then
        exit 0
    fi
    sleep 1
done
exit 1