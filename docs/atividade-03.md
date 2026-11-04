# Atividade 3 — Deploy, systemd, backup e Nginx

**Aluno:** Filipe Rezende Silva
**Usuário GitHub:** filipesilva07
**Repositório:** [ufla-devops-shop](https://github.com/rdurelli/ufla-devops-shop)

## 1. Objetivo

Esta atividade implementa a implantação da aplicação UFLA DevOps Shop em um ambiente Linux, utilizando:

- Script de deploy idempotente;
- Usuário de sistema dedicado para executar a aplicação;
- PostgreSQL e Redis;
- Serviço gerenciado pelo systemd;
- Backup automatizado do banco de dados;
- Timer diário para execução dos backups;
- Nginx como proxy reverso com HTTPS.

## 2. Implantação em uma máquina limpa

### 2.1. Pré-requisitos

O ambiente precisa ter Ubuntu com systemd habilitado, Git e acesso à internet.

Instalar as dependências:

```bash
sudo apt-get update
sudo apt-get install -y git nginx rsync openssl curl python3-venv postgresql postgresql-client redis-server
```

Clonar o repositório:

```bash
git clone https://github.com/rdurelli/ufla-devops-shop.git
cd ufla-devops-shop
```

### 2.2. Preparação do banco de dados

Criar o usuário e o banco PostgreSQL:

```bash
sudo -u postgres psql
```

No prompt do PostgreSQL:

```sql
CREATE USER loja WITH PASSWORD 'DEFINA_UMA_SENHA_SEGURA';
CREATE DATABASE loja OWNER loja;
\q
```

Criar o arquivo de variáveis de ambiente:

```bash
sudo tee /etc/ufla-shop.env > /dev/null <<'ENV'
DATABASE_URL=postgresql://loja:DEFINA_UMA_SENHA_SEGURA@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
ENV

sudo chmod 600 /etc/ufla-shop.env
```

Configurar as credenciais para o backup:

```bash
sudo sh -c "echo 'localhost:5432:loja:loja:DEFINA_UMA_SENHA_SEGURA' > /root/.pgpass"
sudo chmod 600 /root/.pgpass
```

A senha deve ser a mesma definida para o usuário PostgreSQL.

### 2.3. Executar o deploy

```bash
chmod +x scripts/deploy.sh scripts/backup.sh
./scripts/deploy.sh
```

O script prepara o diretório `/opt/ufla-shop`, instala as dependências Python, configura os serviços e valida a disponibilidade da aplicação pelo endpoint `/ready`.

Resultado observado:

```text
Deploy concluído: aplicação pronta!
```

As credenciais ficam em `/etc/ufla-shop.env` e não devem ser versionadas no Git.

## 3. Serviço systemd e recuperação automática

A aplicação é executada pelo serviço `ufla-shop.service`, com usuário dedicado `ufla-shop`, sem privilégios de root.

Principais configurações:

- Usuário: `ufla-shop`;
- Diretório: `/opt/ufla-shop`;
- Inicialização: Uvicorn;
- Endereço: `127.0.0.1:8000`;
- Política de reinício: `Restart=on-failure`.

Verificação do serviço:

```bash
sudo systemctl status ufla-shop --no-pager
```

### 3.1. Teste de reinício automático

Foi realizado o teste de encerramento forçado do processo principal da aplicação:

```bash
sudo systemctl show ufla-shop -p MainPID
```

O PID apresentado pelo comando deve ser utilizado no comando seguinte:

```bash
sudo kill -9 PID_DO_PROCESSO
sleep 5
sudo systemctl status ufla-shop --no-pager
```

O systemd detectou a interrupção e iniciou novamente a aplicação.

Evidências observadas no status:

```text
Active: active (running)
Scheduled restart job, restart counter is at 1.
Started ufla-shop.service
```

O serviço voltou a ficar ativo após o encerramento forçado do processo.

## 4. Backup do banco de dados

O script `scripts/backup.sh` realiza o backup do banco `loja`, compacta o resultado com gzip e mantém os sete backups mais recentes.

Os arquivos são armazenados em:

```text
/var/backups/ufla-shop/
```

Para executar manualmente:

```bash
sudo systemctl start ufla-shop-backup.service
```

Para conferir o resultado:

```bash
sudo systemctl status ufla-shop-backup.service --no-pager
sudo ls -lah /var/backups/ufla-shop/
```

### 4.1. Evidência de execução

Foram gerados três backups com sucesso:

```text
loja-2026-11-03-2033.sql.gz
loja-2026-11-03-2053.sql.gz
loja-2026-11-03-2055.sql.gz
```

Os três arquivos foram apresentados com aproximadamente 1,6 KB cada.

O serviço de backup executou com:

```text
code=exited, status=0/SUCCESS
Backup concluído com sucesso.
```

## 5. Agendamento automático

O timer `ufla-shop-backup.timer` agenda a execução diária do backup às 03:00.

Configurações principais:

- `OnCalendar=*-*-* 03:00:00`;
- `Persistent=true`;
- Serviço associado: `ufla-shop-backup.service`.

Verificação:

```bash
sudo systemctl status ufla-shop-backup.timer --no-pager
```

Resultado observado:

```text
Active: active (waiting)
Trigger: Wed 2026-11-04 03:00:00 -03
Triggers: ufla-shop-backup.service
```

O timer está habilitado e aguardando a próxima execução.

## 6. Nginx e HTTPS

O Nginx atua como proxy reverso para a aplicação, encaminhando as requisições para `127.0.0.1:8000`.

A configuração implementa:

- Redirecionamento HTTP para HTTPS com status 301;
- HTTPS na porta 443;
- Certificado TLS autoassinado para o ambiente de laboratório;
- Encaminhamento dos cabeçalhos da requisição.

O certificado e a chave privada são armazenados fora do repositório:

```text
/etc/ssl/certs/ufla-shop.crt
/etc/ssl/private/ufla-shop.key
```

Validar a configuração:

```bash
sudo nginx -t
```

Resultado:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 6.1. Teste de redirecionamento HTTP

Comando:

```bash
curl -I http://localhost
```

Resultado observado:

```text
HTTP/1.1 301 Moved Permanently
Location: https://localhost/
```

### 6.2. Teste HTTPS

Comando:

```bash
curl -k -i https://localhost/ready
```

Resultado observado:

```text
HTTP/1.1 200 OK
Server: nginx
{"status":"ok","banco":"ok","cache":"ok"}
```

A opção `-k` permite testar o certificado autoassinado utilizado no ambiente de laboratório.

## 7. Teste de idempotência

O script de deploy foi executado novamente após a primeira implantação, sem necessidade de recriar manualmente o ambiente.

Na segunda execução, o usuário de serviço já existia e as dependências estavam instaladas. O script concluiu novamente a implantação e a verificação de saúde.

Resultado da primeira execução:

```text
Deploy concluído: aplicação pronta!
```

Resultado da segunda execução:

```text
Deploy concluído: aplicação pronta!
```

Na segunda execução, houve uma tentativa inicial de conexão recusada durante a inicialização da aplicação. O script aguardou e a aplicação ficou pronta na tentativa seguinte.

Foi observado também um aviso de chave pública ausente no repositório externo HashiCorp durante `apt-get update`. O aviso não impediu a instalação dos pacotes necessários nem a conclusão do deploy.

## 8. Arquivos entregues

```text
scripts/
  deploy.sh
  backup.sh

systemd/
  ufla-shop.service
  ufla-shop-backup.service
  ufla-shop-backup.timer

nginx/
  loja.conf

docs/
  atividade-03.md
```

## 9. Segurança

- A aplicação é executada com usuário de sistema dedicado, sem root.
- As credenciais ficam em `/etc/ufla-shop.env`, com permissão restrita.
- O arquivo `/root/.pgpass` possui permissão `600`.
- A chave privada TLS fica em `/etc/ssl/private/`, fora do repositório.
- Senhas, arquivos de ambiente, certificados e chaves privadas não devem ser enviados ao Git.