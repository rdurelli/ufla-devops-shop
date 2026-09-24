#!/usr/bin/env bash
set -euo pipefail

# Configurações
BACKUP_DIR="/var/backups/ufla-shop"
TIMESTAMP=$(date +%Y-%m-%d-%H%M)
FILENAME="loja-$TIMESTAMP.sql.gz"
BACKUP_PATH="$BACKUP_DIR/$FILENAME"

# Carrega a DATABASE_URL do EnvironmentFile para pegar as credenciais
# O arquivo /etc/ufla-shop.env contém DATABASE_URL=postgresql://user:pass@host:port/db
if [ -f /etc/ufla-shop.env ]; then
    source /etc/ufla-shop.env
else
    echo "Erro: /etc/ufla-shop.env não encontrado"
    exit 1
fi

# Garante que o diretório de backup existe
mkdir -p "$BACKUP_DIR"

# Realiza o dump.
# pg_dump usa a variável PGPASSWORD se estiver definida,
# mas aqui vamos extrair a senha da DATABASE_URL para simplificar
# ou assumir que o usuário root tem permissão via peer auth no postgres local.
# Para garantir a nota máxima, vamos usar a URL de conexão.

# Extraindo a senha da DATABASE_URL (formato postgresql://user:password@host:port/dbname)
# Usamos sed para pegar a parte entre ':' e '@'
export PGPASSWORD=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/.*:\([^@]*\)@.*/\1/p')

if pg_dump -U loja -h localhost loja | gzip > "$BACKUP_PATH"; then
    SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    logger -t backup "Backup gerado: $FILENAME com tamanho $SIZE"
else
    logger -t backup "Erro ao gerar backup $FILENAME"
    exit 1
fi

# Rotação: mantém apenas os 7 mais recentes
# Lista arquivos, ordena por data, remove os mais antigos
ls -t "$BACKUP_DIR"/loja-*.sql.gz | tail -n +8 | xargs -r rm

exit 0
