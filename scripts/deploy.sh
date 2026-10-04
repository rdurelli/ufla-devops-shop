#!/usr/bin/env bash
set -euo pipefail

# Garante execucao como root/sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "ERRO: O script deploy.sh deve ser executado com sudo." >&2
    echo "Uso correto: sudo ./scripts/deploy.sh" >&2
    exit 1
fi

# Funcao de log padronizada (conforme exemplo da aula)
log() { echo "[$(date -Is)] $*" | tee -a /var/log/deploy.log; }

APP_DIR="/opt/ufla-shop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log "Iniciando o deploy do ufla-devops-shop..."

# 1. Criar usuario de sistema (Idempotente)
log "Verificando/criando usuario de sistema ufla-shop..."
id ufla-shop &>/dev/null || useradd -r -s /bin/false ufla-shop

# 2. Sincronizar codigo para /opt/ufla-shop
log "Sincronizando codigo para ${APP_DIR}..."
mkdir -p "${APP_DIR}"
rsync -a \
    --exclude='.venv' \
    --exclude='.git' \
    --exclude='.Xauthority*' \
    --exclude='.cache' \
    "${REPO_DIR}/" "${APP_DIR}/"

cd "${APP_DIR}"

# 3. Criar ambiente virtual e instalar dependencias Python (Idempotente)
log "Configurando venv e instalando dependencias..."
python3 -m venv .venv
./.venv/bin/pip install -q --upgrade pip
./.venv/bin/pip install -qr requirements.txt
chown -R ufla-shop:ufla-shop "${APP_DIR}"

# 4. Configurar variaveis de ambiente (/etc/ufla-shop.env)
log "Verificando arquivo de ambiente /etc/ufla-shop.env..."
if [ ! -f /etc/ufla-shop.env ]; then
    if [ -f "${APP_DIR}/etc/ufla-shop.env.example" ]; then
        cp "${APP_DIR}/etc/ufla-shop.env.example" /etc/ufla-shop.env
    else
        cat << 'ENV' > /etc/ufla-shop.env
DATABASE_URL=postgresql://loja:troque-esta-senha@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
ENV
    fi
    chmod 600 /etc/ufla-shop.env
    chown ufla-shop:ufla-shop /etc/ufla-shop.env 2>/dev/null || true
fi

# 5. Gerar certificado TLS autoassinado para o Nginx (se nao existir)
log "Verificando certificados TLS..."
mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/loja.crt ] || [ ! -f /etc/nginx/ssl/loja.key ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/loja.key \
        -out /etc/nginx/ssl/loja.crt \
        -subj "/CN=localhost" &>/dev/null
fi

# 6. Instalar arquivos de unidade do systemd
log "Instalando arquivos do systemd..."
cp "${APP_DIR}/systemd/ufla-shop.service" /etc/systemd/system/
cp "${APP_DIR}/systemd/ufla-shop-backup.service" /etc/systemd/system/
cp "${APP_DIR}/systemd/ufla-shop-backup.timer" /etc/systemd/system/
chmod +x "${APP_DIR}/scripts/backup.sh" 2>/dev/null || true

# 7. Configurar proxy reverso Nginx
log "Configurando Nginx..."
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
cp "${APP_DIR}/nginx/loja.conf" /etc/nginx/sites-available/loja
ln -sfn /etc/nginx/sites-available/loja /etc/nginx/sites-enabled/loja
rm -f /etc/nginx/sites-enabled/default
nginx -t

# 8. Reiniciar e habilitar servicos
log "Reiniciando e habilitando servicos systemd e Nginx..."
systemctl daemon-reload
systemctl enable ufla-shop.service ufla-shop-backup.timer nginx &>/dev/null || true
systemctl restart ufla-shop.service nginx
systemctl start ufla-shop-backup.timer

# 9. Healthcheck no endpoint http://localhost:8000/ready (ate 10 tentativas com 1s de intervalo)
log "Executando healthcheck em http://localhost:8000/ready..."
HEALTHCHECK_OK=false

for i in $(seq 1 10); do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ready || true)
    if [ "${HTTP_STATUS}" = "200" ]; then
        HEALTHCHECK_OK=true
        log "Healthcheck OK (respondeu 200 na tentativa ${i})"
        break
    fi
    sleep 1
done

if [ "${HEALTHCHECK_OK}" = true ]; then
    log "Deploy do ufla-devops-shop concluido com sucesso!"
else
    log "ERRO: healthcheck nao respondeu 200"
    exit 1
fi
