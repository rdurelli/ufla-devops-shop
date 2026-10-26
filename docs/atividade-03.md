# Atividade 3 — Automatizar de verdade

## Instalação em uma máquina limpa

Com o Fedora 44 e o `systemd` do WSL2 ativos, a instalação é feita a partir da
raiz do repositório:

```bash
sudo ./scripts/deploy.sh
```

O script instala Python, PostgreSQL, Valkey/Redis, Nginx, OpenSSL e as demais
dependências; cria o usuário não-root `ufla-shop`; copia a aplicação para
`/opt/ufla-shop`; cria o ambiente virtual; instala os requisitos; configura o
PostgreSQL; instala as units; gera o certificado autoassinado, se necessário;
e habilita os serviços e o timer.

A senha do banco é gerada durante a primeira execução e fica somente em
`/etc/ufla-shop.env`, que não é versionado.

## Serviço e recuperação

O serviço usa `User=ufla-shop`, `WorkingDirectory=/opt/ufla-shop`,
`EnvironmentFile=/etc/ufla-shop.env` e `Restart=on-failure`.

Prova de recuperação após `SIGKILL`:

```text
Old PID: 15870
New PID: 24208
Active: active (running)
Main PID: 24208 (uvicorn)
ufla-shop.service: Scheduled restart job
ufla-shop.service: Started ufla-devops-shop API
```

## Nginx e TLS

```text
$ curl -kI https://localhost
HTTP/1.1 200 OK
Server: nginx/1.30.5

$ curl -I http://localhost
HTTP/1.1 301 Moved Permanently
Server: nginx/1.30.5
Location: https://localhost/
```

O Nginx escuta nas portas 80 e 443, encaminha para `127.0.0.1:8000` e repassa
`X-Real-IP`, `X-Forwarded-For` e `X-Forwarded-Proto`. A aplicação continua
restrita ao endereço local.

## Backup

O backup é executado por `/opt/ufla-shop/scripts/backup.sh`. Ele usa `pg_dump`
com `pipefail`, compacta o dump, mantém os sete arquivos mais recentes e
registra o resultado com `logger -t backup`.

Após três execuções:

```text
total 20
drwxr-xr-x 2 ufla-shop ufla-shop 4096 Oct  7 16:12 .
drwxr-xr-x 3 root      root      4096 Oct  7 16:07 ..
-rw-r--r-- 1 root      root      1707 Oct  7 16:12 loja-2026-10-07-0942.sql.gz
-rw-r--r-- 1 root      root      1704 Oct  7 16:12 loja-2026-10-07-1912.sql.gz
-rw-r--r-- 1 root      root      1706 Oct  7 16:12 loja-2026-10-08-0057.sql.gz
```

## Timer

```text
NEXT                 LEFT LAST PASSED UNIT                 ACTIVATES
Thu 2026-10-08 03:00  10h  -    -      ufla-shop-backup.timer ufla-shop-backup.service
```

O timer está habilitado, é persistente e executa diariamente às 03:00.

## Idempotência

`deploy.sh` foi executado em duas execuções consecutivas após a instalação
inicial. Ambas terminaram com código 0. A saída final comum foi:

```text
DO
ALTER ROLE
GRANT
GRANT
GRANT
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

O script não duplica usuário, banco, certificado, serviços ou dados e o
healthcheck final em `/ready` confirma banco e cache disponíveis.