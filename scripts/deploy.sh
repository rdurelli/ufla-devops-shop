#!/usr/bin/env bash
#
# deploy.sh --- instala o ufla-devops-shop como servico systemd.
#
# Idempotente: a primeira execucao deixa a aplicacao no ar numa maquina limpa;
# as seguintes nao quebram nem duplicam nada. Pode rodar quantas vezes quiser.
#
#   sudo ./scripts/deploy.sh
#
# O que ele faz, em ordem:
#   1. confere que esta rodando como root e que o systemd esta presente;
#   2. garante usuario de sistema, PostgreSQL e Redis;
#   3. sincroniza o codigo para /opt/ufla-shop e cria o venv;
#   4. cria /etc/ufla-shop.env na primeira execucao (senha aleatoria);
#   5. instala as units do systemd, habilita e (re)inicia o servico;
#   6. instala o Nginx e o certificado autoassinado;
#   7. healthcheck: consulta /ready ate 10 vezes, 1s de intervalo.
#
# Nenhum segredo mora neste arquivo: a senha do banco vai para
# /etc/ufla-shop.env, que a unit carrega com EnvironmentFile.

set -euo pipefail

# ------------------------------------------------------------------ constantes
APP_USER="ufla-shop"
APP_DIR="/opt/ufla-shop"
ENV_FILE="/etc/ufla-shop.env"
ENV_EXAMPLE="/etc/ufla-shop.env.example"
SERVICE="ufla-shop"
BACKUP_DIR="/var/backups/ufla-shop"
PORTA=8000

# Diretorio do repositorio (o script mora em scripts/, entao a raiz e o pai).
ORIGEM="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
erro() { printf '\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------- pre-checagem
[[ $EUID -eq 0 ]] || erro "rode como root: sudo $0"
command -v systemctl >/dev/null || erro "systemd nao encontrado --- esta atividade exige Linux com systemd"
[[ -f "$ORIGEM/requirements.txt" ]] || erro "requirements.txt nao encontrado em $ORIGEM; rode o script de dentro do repositorio"

# Descobre o gerenciador de pacotes uma vez so.
if command -v apt-get >/dev/null; then
  PKG=apt
elif command -v dnf >/dev/null; then
  PKG=dnf
else
  erro "gerenciador de pacotes nao suportado (esperado apt-get ou dnf)"
fi

instalar() {
  # instalar <pacote...> --- instala so o que falta, e nao reinstala nada.
  local faltando=()
  for p in "$@"; do
    case "$PKG" in
      apt) dpkg -s "$p" >/dev/null 2>&1 || faltando+=("$p") ;;
      dnf) rpm -q "$p" >/dev/null 2>&1 || faltando+=("$p") ;;
    esac
  done
  ((${#faltando[@]})) || return 0
  log "instalando: ${faltando[*]}"
  case "$PKG" in
    apt) DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${faltando[@]}" ;;
    dnf) dnf install -y -q "${faltando[@]}" ;;
  esac
}

# ------------------------------------------------------- 1. usuario e servicos
# O `id ... || useradd` e o que torna o script reexecutavel: useradd falha com
# "user already exists" e, com set -e, mataria o script na segunda execucao.
if id "$APP_USER" &>/dev/null; then
  log "usuario $APP_USER ja existe"
else
  log "criando usuario de sistema $APP_USER"
  useradd --system --no-create-home --home-dir "$APP_DIR" --shell /usr/sbin/nologin "$APP_USER"
fi

log "garantindo PostgreSQL, Redis, Nginx e Python"
# Os nomes dos pacotes e das units mudam entre Debian/Ubuntu e Fedora:
#   Redis: redis-server/redis-server.service  x  redis/redis.service
if [[ "$PKG" == apt ]]; then
  REDIS_UNIT=redis-server
  instalar postgresql redis-server nginx python3-venv python3-pip openssl rsync
else
  REDIS_UNIT=redis
  instalar postgresql-server redis nginx python3 openssl rsync
fi

log "habilitando e iniciando PostgreSQL e Redis"
systemctl enable --now postgresql
systemctl enable --now "$REDIS_UNIT"

# ------------------------------------------------------ 2. banco e credenciais
# A senha e gerada uma unica vez. Nas execucoes seguintes ela e lida do
# EnvironmentFile --- e por isso que este arquivo nao pode ser sobrescrito.
if [[ -f "$ENV_FILE" ]]; then
  log "lendo segredos de $ENV_FILE"
  # O sed aceita '@' dentro da senha (por isso '.*' guloso ate o ultimo '@'
  # antes do host), coisa que um grep de classe [^@]+ nao aceitaria.
  SENHA_BANCO="$(sed -n 's|^DATABASE_URL=postgresql://loja:\(.*\)@localhost:5432/loja$|\1|p' "$ENV_FILE")"
  [[ -n "$SENHA_BANCO" ]] || erro "nao consegui extrair a senha de $ENV_FILE; apague o arquivo para recriar"
else
  log "gerando segredos em $ENV_FILE (primeira execucao)"
  SENHA_BANCO="$(openssl rand -hex 16)"

  cat > "$ENV_EXAMPLE" <<'EXEMPLO'
# Copie para /etc/ufla-shop.env e troque a senha.
# O deploy.sh cria este arquivo sozinho na primeira execucao.
DATABASE_URL=postgresql://loja:troque-esta-senha@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
CACHE_TTL=30
EXEMPLO
  chmod 644 "$ENV_EXAMPLE"

  cat > "$ENV_FILE" <<EOF
DATABASE_URL=postgresql://loja:${SENHA_BANCO}@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
CACHE_TTL=30
EOF
  chmod 600 "$ENV_FILE"
  chown root:root "$ENV_FILE"
fi

# CREATE USER/DB sao idempotentes pelo teste no catalogo do PostgreSQL.
log "garantindo usuario e banco 'loja'"
como_postgres() { sudo -u postgres psql -tAc "$1"; }

if [[ "$(como_postgres "SELECT 1 FROM pg_roles WHERE rolname='loja'")" != "1" ]]; then
  # A senha entra por stdin do psql, nunca como argumento: argumento aparece
  # no `ps` para qualquer usuario da maquina.
  printf "%s\n" "CREATE USER loja WITH PASSWORD '${SENHA_BANCO}';" | sudo -u postgres psql -q
else
  printf "%s\n" "ALTER USER loja WITH PASSWORD '${SENHA_BANCO}';" | sudo -u postgres psql -q
fi

if [[ "$(como_postgres "SELECT 1 FROM pg_database WHERE datname='loja'")" != "1" ]]; then
  sudo -u postgres psql -q -c "CREATE DATABASE loja OWNER loja;"
fi

# ------------------------------------------------------------- 3. codigo e venv
log "sincronizando o codigo para $APP_DIR"
install -d -o "$APP_USER" -g "$APP_USER" -m 755 "$APP_DIR"

# --delete remove arquivos que sairam do repositorio, mas preserva o venv.
# --no-owner/--no-group sao essenciais: sem eles o rsync copiaria o dono do
# diretorio de origem (o seu usuario na maquina de quem roda o deploy) e o
# ufla-shop perderia a escrita em /opt/ufla-shop antes de criar o venv.
if command -v rsync >/dev/null; then
  rsync -rlptD --delete --no-owner --no-group \
    --exclude '.git' --exclude '.venv' --exclude '__pycache__' \
    --exclude '.pytest_cache' --exclude '.ruff_cache' \
    "$ORIGEM"/ "$APP_DIR"/
else
  erro "rsync nao encontrado; instale-o e rode de novo"
fi

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

# O usuario e de sistema e nao tem home; sem HOME explicito o pip e o venv
# tentam escrever no diretorio do root e reclamam de permissao.
como_app() { sudo -u "$APP_USER" env HOME="$APP_DIR" "$@"; }

if [[ -x "$APP_DIR/.venv/bin/python" ]] && "$APP_DIR/.venv/bin/python" -c 'import sys' 2>/dev/null; then
  log "venv ja existe, reutilizando"
else
  log "criando o venv em $APP_DIR/.venv"
  rm -rf "$APP_DIR/.venv"
  como_app python3 -m venv "$APP_DIR/.venv"
fi

log "instalando requirements.txt"
como_app "$APP_DIR/.venv/bin/pip" install --quiet --upgrade pip
como_app "$APP_DIR/.venv/bin/pip" install --quiet -r "$APP_DIR/requirements.txt"

# ------------------------------------------------------------ 4. backup diario
log "preparando $BACKUP_DIR"
install -d -o "$APP_USER" -g "$APP_USER" -m 750 "$BACKUP_DIR"

# O pg_dump roda sem senha no comando: o .pgpass abaixo e o que resolve o
# "pg_dump pede senha" citado no enunciado.
PGPASS="$APP_DIR/.pgpass"
printf 'localhost:5432:loja:loja:%s\n' "$SENHA_BANCO" > "$PGPASS"
chown "$APP_USER:$APP_USER" "$PGPASS"
chmod 600 "$PGPASS"

# ------------------------------------------------------------ 5. units systemd
log "instalando as units em /etc/systemd/system"
install -m 644 "$ORIGEM/systemd/${SERVICE}.service"        "/etc/systemd/system/${SERVICE}.service"
install -m 644 "$ORIGEM/systemd/${SERVICE}-backup.service" "/etc/systemd/system/${SERVICE}-backup.service"
install -m 644 "$ORIGEM/systemd/${SERVICE}-backup.timer"   "/etc/systemd/system/${SERVICE}-backup.timer"

# O backup.sh precisa saber de onde ler o .pgpass e onde escrever os dumps.
install -m 750 -o "$APP_USER" -g "$APP_USER" "$ORIGEM/scripts/backup.sh" "$APP_DIR/scripts/backup.sh"

systemctl daemon-reload
systemctl enable "${SERVICE}.service"
systemctl restart "${SERVICE}.service"
systemctl enable --now "${SERVICE}-backup.timer"

# ------------------------------------------------------------------ 6. Nginx
log "instalando o Nginx e o certificado autoassinado"
install -d -m 755 /etc/nginx/ssl

if [[ -f /etc/nginx/ssl/loja.pem && -f /etc/nginx/ssl/loja.key ]]; then
  log "certificado ja existe, mantendo"
else
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout /etc/nginx/ssl/loja.key \
    -out /etc/nginx/ssl/loja.pem \
    -subj "/C=BR/ST=MG/L=Lavras/O=UFLA/OU=DCC/CN=localhost" >/dev/null 2>&1
  chmod 600 /etc/nginx/ssl/loja.key
  chmod 644 /etc/nginx/ssl/loja.pem
fi

install -m 644 "$ORIGEM/nginx/loja.conf" /etc/nginx/conf.d/loja.conf

# `http2 on;` so existe a partir do nginx 1.25. No 1.24 (Ubuntu 24.04) a
# diretiva e desconhecida e derruba o `nginx -t` inteiro, entao ela sai.
NGINX_VERSAO="$(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
# `sort -V -C` sai 0 quando a entrada JA esta em ordem de versao. Se ordenar
# "1.25 $NGINX_VERSAO" nao muda nada, entao 1.25 <= versao instalada.
if [[ -n "$NGINX_VERSAO" ]] && ! printf '1.25\n%s\n' "$NGINX_VERSAO" | sort -V -C; then
  log "nginx ${NGINX_VERSAO}: removendo a diretiva 'http2 on' (so existe no 1.25+)"
  sed -i '/^\s*http2 on;\s*$/d' /etc/nginx/conf.d/loja.conf
fi

# Em Debian/Ubuntu o site default ocupa a porta 80 e ganha do nosso server.
if [[ -e /etc/nginx/sites-enabled/default ]]; then
  rm -f /etc/nginx/sites-enabled/default
fi

nginx -t >/dev/null || erro "configuracao do Nginx invalida; rode 'nginx -t' para ver"
systemctl enable --now nginx
# O reload so funciona se o Nginx ja estava rodando; senao, restart.
systemctl reload nginx 2>/dev/null || systemctl restart nginx

# ------------------------------------------------------------- 7. healthcheck
log "healthcheck: http://localhost:${PORTA}/ready"
resposta=""
for tentativa in $(seq 1 10); do
  if resposta="$(curl -fsS "http://localhost:${PORTA}/ready" 2>/dev/null)"; then
    log "aplicacao no ar: ${resposta}"
    log "deploy concluido"
    exit 0
  fi
  log "  tentativa ${tentativa}/10 sem resposta, aguardando 1s"
  sleep 1
done

erro "a aplicacao nao respondeu 200 em /ready apos 10 tentativas --- veja: journalctl -u ${SERVICE} -n 50"
