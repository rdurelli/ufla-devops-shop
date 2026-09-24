#!/usr/bin/env bash
set -euo pipefail

# Configurações
APP_USER="ufla-shop"
APP_DIR="/opt/ufla-shop"
ENV_FILE="/etc/ufla-shop.env"
ENV_EXAMPLE="/etc/ufla-shop.env.example"

echo "--- Iniciando deploy da UFLA DevOps Shop ---"

# 1. Criar usuário de sistema se não existir
if id "$APP_USER" &>/dev/null; then
    echo "Usuário $APP_USER já existe."
else
    echo "Criando usuário $APP_USER..."
    useradd -m -s /bin/bash "$APP_USER"
fi

# 2. Configurar segredos (/etc/ufla-shop.env)
if [ ! -f "$ENV_FILE" ]; then
    echo "Criando $ENV_FILE a partir do exemplo..."
    # Cria o exemplo primeiro se não existir no repo (simulando a existência)
    # Na prática, o deploy.sh deve garantir que o exemplo exista ou criar um padrão.
    cat <<EOF > "$ENV_EXAMPLE"
DATABASE_URL=postgresql://loja:troque-esta-senha@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
EOF
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "ATENÇÃO: Edite $ENV_FILE com as senhas reais!"
else
    echo "Arquivo de ambiente $ENV_FILE já existe."
fi

# 3. Sincronizar código e preparar ambiente
echo "Sincronizando código para $APP_DIR..."
mkdir -p "$APP_DIR"
# Copia arquivos do repositório atual para /opt (ignora .git)
rsync -av --exclude='.git/' . "$APP_DIR/"
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

echo "Configurando venv..."
sudo -u "$APP_USER" bash -c "
    cd $APP_DIR
    [ -d .venv ] || python3 -m venv .venv
    . .venv/bin/activate
    pip install -r requirements.txt
"

# 4. Instalar artefatos do systemd
echo "Instalando units do systemd..."
cp systemd/ufla-shop.service /etc/systemd/system/
cp systemd/ufla-shop-backup.service /etc/systemd/system/
cp systemd/ufla-shop-backup.timer /etc/systemd/system/
# Instala o script de backup no caminho esperado pela unit
mkdir -p /usr/local/bin
cp scripts/backup.sh /usr/local/bin/ufla-shop-backup.sh
chmod +x /usr/local/bin/ufla-shop-backup.sh

systemctl daemon-reload
systemctl enable ufla-shop.service
systemctl enable ufla-shop-backup.timer

echo "Reiniciando serviço..."
systemctl restart ufla-shop.service

# 5. Certificado TLS autoassinado para o Nginx
echo "Gerando certificado TLS autoassinado..."
mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/loja.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/loja.key \
        -out /etc/nginx/ssl/loja.crt \
        -subj "/C=BR/ST=MG/L=Llavras/O=UFLA/CN=localhost"
fi

# Instalar config do Nginx
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
cp nginx/loja.conf /etc/nginx/sites-available/loja.conf
ln -sf /etc/nginx/sites-available/loja.conf /etc/nginx/sites-enabled/loja.conf
systemctl restart nginx || echo "Aviso: Nginx não instalado ou falhou ao reiniciar."

# 6. Healthcheck final
echo "Executando healthcheck..."
COUNT=0
until curl -s http://localhost:8000/ready | grep -q '"banco":"ok","cache":"ok"'; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge 10 ]; then
        echo "ERRO: Aplicação não ficou pronta após 10 tentativas."
        exit 1
    fi
    echo "Aguardando aplicação... ($COUNT/10)"
    sleep 1
done

echo "--- Deploy concluído com sucesso! ---"
exit 0
