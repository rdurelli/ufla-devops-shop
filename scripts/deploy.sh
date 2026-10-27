#!/usr/bin/env bash
#
# deploy.sh — instala e (re)inicia o ufla-devops-shop como serviço systemd.
# Idempotente: pode ser executado repetidas vezes sem quebrar nem duplicar nada.
#
# Uso: sudo ./deploy.sh
# Deve ser executado a partir da raiz do repositório (onde estão app/, static/,
# requirements.txt, systemd/, nginx/).

set -euo pipefail

# --------------------------------------------------------------------------
# Configuração
# --------------------------------------------------------------------------
APP_USER="ufla-shop"
APP_GROUP="ufla-shop"
APP_DIR="/opt/ufla-shop"
ENV_FILE="/etc/ufla-shop.env"
ENV_EXAMPLE="/etc/ufla-shop.env.example"
SYSTEMD_DIR="/etc/systemd/system"
NGINX_DIR="/etc/nginx"
CERT_DIR="/etc/nginx/ssl"
SERVICE_NAME="ufla-shop.service"
BACKUP_SERVICE_NAME="ufla-shop-backup.service"
BACKUP_TIMER_NAME="ufla-shop-backup.timer"
HEALTH_URL="http://localhost:8000/ready"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
    echo "[deploy] $*"
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Este script precisa ser executado como root (use sudo)." >&2
        exit 1
    fi
}

# --------------------------------------------------------------------------
# 1. Usuário de sistema (não-root)
# --------------------------------------------------------------------------
create_app_user() {
    if id "${APP_USER}" &>/dev/null; then
        log "Usuário ${APP_USER} já existe, pulando criação."
    else
        log "Criando usuário de sistema ${APP_USER}..."
        useradd --system --shell /usr/sbin/nologin --home-dir "${APP_DIR}" --create-home "${APP_USER}"
    fi
}

# --------------------------------------------------------------------------
# 2. Código, venv e dependências
# --------------------------------------------------------------------------
sync_code() {
    log "Sincronizando código para ${APP_DIR}..."
    mkdir -p "${APP_DIR}"
    rsync -a --delete \
        --exclude '.git' \
        --exclude '.venv' \
        --exclude '__pycache__' \
        "${REPO_DIR}/" "${APP_DIR}/"
    chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"
}

setup_venv() {
    if [[ -d "${APP_DIR}/.venv" ]]; then
        log "Virtualenv já existe, atualizando dependências..."
    else
        log "Criando virtualenv em ${APP_DIR}/.venv..."
        sudo -u "${APP_USER}" python3 -m venv "${APP_DIR}/.venv"
    fi
    sudo -u "${APP_USER}" "${APP_DIR}/.venv/bin/pip" install --upgrade pip --quiet
    sudo -u "${APP_USER}" "${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt" --quiet
}

# --------------------------------------------------------------------------
# 3. Segredos: /etc/ufla-shop.env (nunca no script/versionado)
# --------------------------------------------------------------------------
setup_env_file() {
    if [[ -f "${ENV_FILE}" ]]; then
        log "${ENV_FILE} já existe, mantendo como está."
    else
        if [[ -f "${APP_DIR}/${ENV_EXAMPLE##*/}" ]]; then
            log "Criando ${ENV_FILE} a partir do exemplo do repositório..."
            cp "${APP_DIR}/${ENV_EXAMPLE##*/}" "${ENV_FILE}"
        elif [[ -f "${ENV_EXAMPLE}" ]]; then
            log "Criando ${ENV_FILE} a partir de ${ENV_EXAMPLE}..."
            cp "${ENV_EXAMPLE}" "${ENV_FILE}"
        else
            log "AVISO: nenhum ${ENV_EXAMPLE} encontrado; criando ${ENV_FILE} vazio."
            touch "${ENV_FILE}"
        fi
        chown root:"${APP_GROUP}" "${ENV_FILE}"
        chmod 640 "${ENV_FILE}"
        log "Edite ${ENV_FILE} com as credenciais reais antes de seguir, se necessário."
    fi
}

# --------------------------------------------------------------------------
# 4. Certificado autoassinado para o Nginx (não versionado)
# --------------------------------------------------------------------------
setup_tls_cert() {
    mkdir -p "${CERT_DIR}"
    if [[ -f "${CERT_DIR}/loja.crt" && -f "${CERT_DIR}/loja.key" ]]; then
        log "Certificado TLS já existe em ${CERT_DIR}, pulando geração."
    else
        log "Gerando certificado autoassinado..."
        openssl req -x509 -nodes -days 365 \
            -newkey rsa:2048 \
            -keyout "${CERT_DIR}/loja.key" \
            -out "${CERT_DIR}/loja.crt" \
            -subj "/C=BR/ST=MG/L=Lavras/O=UFLA/CN=localhost"
        chmod 600 "${CERT_DIR}/loja.key"
    fi
}

setup_nginx() {
    if [[ ! -f "${APP_DIR}/nginx/loja.conf" ]]; then
        log "Nenhum nginx/loja.conf encontrado no repositório, pulando configuração do Nginx."
        return 0
    fi

    if ! command -v nginx &>/dev/null; then
        log "Nginx não encontrado, instalando..."
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y nginx
        elif command -v dnf &>/dev/null; then
            dnf install -y nginx
        else
            echo "[deploy] ERRO: nenhum gerenciador de pacotes suportado (apt/dnf) para instalar o Nginx." >&2
            exit 1
        fi
    fi

    log "Instalando configuração do Nginx..."
    if [[ -d "${NGINX_DIR}/sites-available" ]]; then
        # Layout Debian/Ubuntu
        cp "${APP_DIR}/nginx/loja.conf" "${NGINX_DIR}/sites-available/loja.conf"
        mkdir -p "${NGINX_DIR}/sites-enabled"
        ln -sf "${NGINX_DIR}/sites-available/loja.conf" "${NGINX_DIR}/sites-enabled/loja.conf"
        # Remove o site default se existir, para não disputar a porta 80/443
        rm -f "${NGINX_DIR}/sites-enabled/default"
    else
        # Layout Fedora/RHEL (sem sites-available)
        mkdir -p "${NGINX_DIR}/conf.d"
        cp "${APP_DIR}/nginx/loja.conf" "${NGINX_DIR}/conf.d/loja.conf"
    fi

    nginx -t
    systemctl enable nginx
    systemctl reload nginx 2>/dev/null || systemctl restart nginx
}

# --------------------------------------------------------------------------
# 5. Units do systemd
# --------------------------------------------------------------------------
install_systemd_units() {
    log "Instalando units do systemd..."
    cp "${APP_DIR}/systemd/${SERVICE_NAME}" "${SYSTEMD_DIR}/${SERVICE_NAME}"
    cp "${APP_DIR}/systemd/${BACKUP_SERVICE_NAME}" "${SYSTEMD_DIR}/${BACKUP_SERVICE_NAME}"
    cp "${APP_DIR}/systemd/${BACKUP_TIMER_NAME}" "${SYSTEMD_DIR}/${BACKUP_TIMER_NAME}"

    log "Recarregando systemd..."
    systemctl daemon-reload

    log "Habilitando e (re)iniciando ${SERVICE_NAME}..."
    systemctl enable "${SERVICE_NAME}"
    systemctl restart "${SERVICE_NAME}"

    log "Habilitando e iniciando ${BACKUP_TIMER_NAME}..."
    systemctl enable --now "${BACKUP_TIMER_NAME}"
}

# --------------------------------------------------------------------------
# 6. Healthcheck final
# --------------------------------------------------------------------------
healthcheck() {
    log "Aguardando ${SERVICE_NAME} responder em ${HEALTH_URL}..."
    local attempt
    for attempt in $(seq 1 10); do
        if curl -sf -o /dev/null "${HEALTH_URL}"; then
            log "Healthcheck OK na tentativa ${attempt}."
            curl -s "${HEALTH_URL}"
            echo
            log "Deploy concluído com sucesso."
            return 0
        fi
        log "Tentativa ${attempt}/10 falhou, aguardando 1s..."
        sleep 1
    done

    echo "[deploy] ERRO: ${HEALTH_URL} não respondeu 200 após 10 tentativas." >&2
    exit 1
}

# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
main() {
    require_root
    create_app_user
    sync_code
    setup_venv
    setup_env_file
    setup_tls_cert
    install_systemd_units
    setup_nginx
    healthcheck
}

main "$@"