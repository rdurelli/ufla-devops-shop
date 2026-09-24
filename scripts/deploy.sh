#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly APP_NAME="ufla-shop"
readonly APP_USER="ufla-shop"
readonly APP_DIR="/opt/${APP_NAME}"
readonly SERVICE_UNIT="${APP_NAME}.service"
readonly BACKUP_DIR="/var/backups/${APP_NAME}"
readonly ENV_EXAMPLE_SOURCE="${PROJECT_DIR}/ufla-shop.env.example"
readonly ENV_EXAMPLE="/etc/${APP_NAME}.env.example"
readonly ENV_FILE="/etc/${APP_NAME}.env"
readonly TLS_DIR="/etc/ssl/${APP_NAME}"
readonly TLS_CERT="${TLS_DIR}/localhost.pem"
readonly TLS_KEY="${TLS_DIR}/localhost.key"

fail() {
    printf 'ERRO: %s\n' "$*" >&2
    exit 1
}

if (( EUID != 0 )); then
    fail "execute como root: sudo $0"
fi

if [[ ! -d /run/systemd/system ]] || ! command -v systemctl >/dev/null 2>&1; then
    fail "systemd não está ativo nesta máquina"
fi

required_files=(
    "requirements.txt"
    "ufla-shop.env.example"
    "scripts/backup.sh"
    "systemd/ufla-shop.service"
    "systemd/ufla-shop-backup.service"
    "systemd/ufla-shop-backup.timer"
    "nginx/loja.conf"
)
for relative_path in "${required_files[@]}"; do
    [[ -f "${PROJECT_DIR}/${relative_path}" ]] || fail "arquivo obrigatório ausente: ${relative_path}"
done

apt_packages=()
dnf_packages=()

if ! command -v python3 >/dev/null 2>&1; then
    apt_packages+=(python3-venv)
    dnf_packages+=(python3)
elif ! python3 -m venv --help >/dev/null 2>&1; then
    apt_packages+=(python3-venv)
    dnf_packages+=(python3)
fi
if ! command -v rsync >/dev/null 2>&1; then
    apt_packages+=(rsync)
    dnf_packages+=(rsync)
fi
if ! command -v curl >/dev/null 2>&1; then
    apt_packages+=(curl)
    dnf_packages+=(curl)
fi
if ! command -v openssl >/dev/null 2>&1; then
    apt_packages+=(openssl)
    dnf_packages+=(openssl)
fi
if ! command -v nginx >/dev/null 2>&1; then
    apt_packages+=(nginx)
    dnf_packages+=(nginx)
fi
if ! command -v pg_dump >/dev/null 2>&1; then
    apt_packages+=(postgresql-client)
    dnf_packages+=(postgresql)
fi

if (( ${#apt_packages[@]} > 0 )); then
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${apt_packages[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "${dnf_packages[@]}"
    else
        fail "instale manualmente python3-venv, rsync, curl, openssl, nginx e postgresql-client"
    fi
fi

if ! id "${APP_USER}" >/dev/null 2>&1; then
    useradd --system --user-group \
        --home-dir "${APP_DIR}" \
        --no-create-home \
        --shell /usr/sbin/nologin \
        "${APP_USER}"
fi

install -d -o root -g "${APP_USER}" -m 0750 "${APP_DIR}"
install -d -o "${APP_USER}" -g "${APP_USER}" -m 0750 "${BACKUP_DIR}"

install -o root -g root -m 0644 "${ENV_EXAMPLE_SOURCE}" "${ENV_EXAMPLE}"
if [[ ! -e "${ENV_FILE}" ]]; then
    install -o root -g root -m 0600 "${ENV_EXAMPLE}" "${ENV_FILE}"
else
    chown root:root "${ENV_FILE}"
    chmod 0600 "${ENV_FILE}"
fi

if [[ -e "/etc/systemd/system/${SERVICE_UNIT}" ]]; then
    systemctl stop "${SERVICE_UNIT}"
fi

rsync -a --delete \
    --exclude='.git/' \
    --exclude='.venv/' \
    --exclude='venv/' \
    --exclude='__pycache__/' \
    --exclude='.pytest_cache/' \
    --exclude='.ruff_cache/' \
    --exclude='.env' \
    --exclude='.env.*' \
    --exclude='*.pem' \
    --exclude='*.key' \
    --exclude='*.db' \
    --exclude='*.db-journal' \
    --exclude='dados/' \
    "${PROJECT_DIR}/" "${APP_DIR}/"

python3 -m venv "${APP_DIR}/.venv"
"${APP_DIR}/.venv/bin/python" -m pip install \
    --no-cache-dir \
    -r "${APP_DIR}/requirements.txt"
chown -R "root:${APP_USER}" "${APP_DIR}"
chmod -R go-w "${APP_DIR}"

for unit_name in \
    "${APP_NAME}.service" \
    "${APP_NAME}-backup.service" \
    "${APP_NAME}-backup.timer"; do
    install -o root -g root -m 0644 \
        "${PROJECT_DIR}/systemd/${unit_name}" \
        "/etc/systemd/system/${unit_name}"
done

install -d -o root -g root -m 0755 "${TLS_DIR}"
if [[ ! -s "${TLS_CERT}" || ! -s "${TLS_KEY}" ]]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${TLS_KEY}" \
        -out "${TLS_CERT}" \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
    chown root:root "${TLS_CERT}" "${TLS_KEY}"
    chmod 0644 "${TLS_CERT}"
    chmod 0600 "${TLS_KEY}"
fi

install -D -o root -g root -m 0644 \
    "${PROJECT_DIR}/nginx/loja.conf" \
    /etc/nginx/sites-available/loja.conf
ln -sfn /etc/nginx/sites-available/loja.conf /etc/nginx/sites-enabled/loja.conf
nginx -t

systemctl daemon-reload
systemctl enable "${SERVICE_UNIT}"
systemctl restart "${SERVICE_UNIT}"
systemctl enable --now "${APP_NAME}-backup.timer"
systemctl enable nginx.service
systemctl restart nginx.service

for attempt in {1..10}; do
    status="$(curl --silent --connect-timeout 1 --max-time 2 \
        --output /dev/null --write-out '%{http_code}' \
        http://localhost:8000/ready || true)"
    if [[ "${status}" == "200" ]]; then
        printf 'Healthcheck OK: HTTP 200 na tentativa %s/10.\n' "${attempt}"
        exit 0
    fi

    printf 'Healthcheck %s/10: HTTP %s.\n' \
        "${attempt}" "${status:-sem resposta}" >&2
    if (( attempt < 10 )); then
        sleep 1
    fi
done

printf 'A aplicação não respondeu HTTP 200 em http://localhost:8000/ready.\n' >&2
systemctl status "${SERVICE_UNIT}" --no-pager >&2 || true
exit 1
