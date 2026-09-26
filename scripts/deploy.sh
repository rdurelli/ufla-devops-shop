#!/usr/bin/env bash
set -euo pipefail

# deploy.sh — deixa o ufla-devops-shop no ar como servico systemd.
#
# Idempotente: pode rodar quantas vezes quiser, numa maquina limpa ou em cima
# de uma instalacao anterior. Faz, em ordem:
#   1. instala as dependencias do SO (apt-get; Fedora: veja o aviso abaixo);
#   2. cria o usuario de sistema nao-root `ufla-shop`;
#   3. gera /etc/ufla-shop.env a partir do exemplo (senha aleatoria do banco);
#   4. garante PostgreSQL e Redis no ar + role `loja` e banco `loja`;
#   5. sincroniza o codigo para /opt/ufla-shop e instala o venv;
#   6. instala e (re)inicia as units do systemd;
#   7. instala o Nginx a frente com TLS autoassinado;
#   8. healthcheck final em /ready.
#
# Rodar:  sudo ./scripts/deploy.sh

APP_USER="ufla-shop"
APP_DIR="/opt/ufla-shop"
ENV_FILE="/etc/ufla-shop.env"
ENV_EXAMPLE="/etc/ufla-shop.env.example"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "ERRO: rode como root — sudo $0" >&2
  exit 1
fi

# ----------------------------------------------------------- 1. dependencias
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null
  apt-get install -y python3-venv postgresql redis-server nginx openssl curl >/dev/null
else
  echo "AVISO: apt-get ausente. Instale a mao: python3-venv postgresql redis nginx openssl curl" >&2
fi

# -------------------------------------------------- 2. usuario do sistema
id "$APP_USER" &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER"

# ------------------------------------------------------ 3. arquivo de segredos
install -m 644 "$REPO_DIR/systemd/ufla-shop.env.example" "$ENV_EXAMPLE"
if [[ ! -f "$ENV_FILE" ]]; then
  DB_PASSWORD="$(openssl rand -hex 16)"
  sed "s/CHANGE-ME/${DB_PASSWORD}/" "$ENV_EXAMPLE" > "$ENV_FILE"
  chown root:root "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo ">> $ENV_FILE criado com senha de banco aleatoria"
fi

# ------------------------------------- 4. banco e cache: servicos + role/db
systemctl enable --now postgresql.service
if systemctl list-unit-files redis-server.service >/dev/null 2>&1; then
  systemctl enable --now redis-server.service
elif systemctl list-unit-files redis.service >/dev/null 2>&1; then
  systemctl enable --now redis.service
fi

# espera o postgres aceitar conexoes (ate ~10s)
for i in $(seq 1 10); do
  if sudo -u postgres psql -tAc "SELECT 1" >/dev/null 2>&1; then break; fi
  sleep 1
done

DB_URL="$(grep -E '^DATABASE_URL=' "$ENV_FILE" | head -n1 | cut -d= -f2-)"
DB_PASSWORD="$(printf '%s' "$DB_URL" | sed -E 's#^postgresql://[^:]+:([^@]+)@.*#\1#')"

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='loja'" | grep -q 1; then
  sudo -u postgres psql -c "ALTER ROLE loja WITH LOGIN PASSWORD '${DB_PASSWORD}'" >/dev/null
else
  sudo -u postgres psql -c "CREATE ROLE loja LOGIN PASSWORD '${DB_PASSWORD}'" >/dev/null
fi
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='loja'" | grep -q 1; then
  sudo -u postgres createdb -O loja loja
fi

# ------------------------------------------- 5. codigo + venv (sincronizado)
mkdir -p "$APP_DIR/app" "$APP_DIR/static" "$APP_DIR/scripts"
cp -a "$REPO_DIR/app/."    "$APP_DIR/app/"
cp -a "$REPO_DIR/static/." "$APP_DIR/static/"
install -m 644 "$REPO_DIR/requirements.txt" "$APP_DIR/requirements.txt"
install -m 755 "$REPO_DIR/scripts/backup.sh" "$APP_DIR/scripts/backup.sh"

if [[ ! -d "$APP_DIR/.venv" ]]; then
  python3 -m venv "$APP_DIR/.venv"
fi
"$APP_DIR/.venv/bin/pip" install --quiet -r "$APP_DIR/requirements.txt"

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

# ---------------------------------------------------------- 6. units systemd
install -m 644 "$REPO_DIR/systemd/ufla-shop.service"        /etc/systemd/system/
install -m 644 "$REPO_DIR/systemd/ufla-shop-backup.service" /etc/systemd/system/
install -m 644 "$REPO_DIR/systemd/ufla-shop-backup.timer"   /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now ufla-shop-backup.timer
systemctl enable ufla-shop.service
systemctl restart ufla-shop.service

# ------------------------------------- 7. nginx: TLS autoassinado + proxy
if [[ ! -f /etc/nginx/ssl/ufla-shop.crt ]]; then
  mkdir -p /etc/nginx/ssl
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/ufla-shop.key \
    -out /etc/nginx/ssl/ufla-shop.crt \
    -subj "/CN=localhost" >/dev/null 2>&1
fi
install -m 644 "$REPO_DIR/nginx/loja.conf" /etc/nginx/conf.d/loja.conf
rm -f /etc/nginx/sites-enabled/default   # evita conflito na porta 80
systemctl enable --now nginx.service
systemctl reload nginx.service

# -------------------------------------------------------- 8. healthcheck final
echo ">> healthcheck em http://localhost:8000/ready"
for i in $(seq 1 10); do
  if curl -fsS -o /dev/null http://localhost:8000/ready; then
    echo ">> /ready respondeu 200 na tentativa ${i}"
    exit 0
  fi
  sleep 1
done
echo "ERRO: /ready nao respondeu 200 em 10 tentativas" >&2
exit 1
