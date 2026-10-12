# Atividade 3 — Automatizar de verdade

A `ufla-devops-shop` rodando como serviço Linux: instalada pelo `deploy.sh` (idempotente),
gerenciada pelo systemd, com backup diário agendado e o Nginx à frente fazendo TLS.

| Arquivo | Função |
|---|---|
| `scripts/deploy.sh` | Instala e sobe a aplicação; termina com healthcheck em `/ready` |
| `scripts/backup.sh` | `pg_dump` compactado, mantém os 7 mais recentes, registra no journal |
| `systemd/ufla-shop.service` | Serviço da API (usuário `ufla-shop`, `Restart=on-failure`) |
| `systemd/ufla-shop-backup.service` | `Type=oneshot` que executa o `backup.sh` |
| `systemd/ufla-shop-backup.timer` | Dispara o backup todo dia às 3h |
| `systemd/ufla-shop.env.example` | Modelo do `/etc/ufla-shop.env` (sem a senha real) |
| `nginx/loja.conf` | Redirecionamento 80 → 443, TLS e proxy para `127.0.0.1:8000` |

## (a) Como rodar o `deploy.sh` numa máquina limpa

Pré-requisito: Ubuntu/Debian com systemd. Rode tudo a partir da raiz do repositório.

**1. Preparar o banco** (uma vez só; o `deploy.sh` instala o PostgreSQL, mas não cria banco nem senha):

```bash
sudo apt install -y postgresql
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'SUA_SENHA';"
sudo -u postgres psql -c 'CREATE DATABASE "ufla-devops-shop";'
```

**2. Primeira execução** — cria `/etc/ufla-shop.env` a partir do modelo e para, pedindo a senha:

```bash
sudo ./scripts/deploy.sh
sudo nano /etc/ufla-shop.env     # trocar TROQUE_A_SENHA pela senha real
```

A senha fica só em `/etc/ufla-shop.env` (permissão 600), nunca no repositório.

**3. Segunda execução** — instala tudo e sobe a aplicação:

```bash
sudo ./scripts/deploy.sh         # termina com "OK: aplicacao no ar"
```

## (b) `systemctl status` depois do `kill -9`

O `pidof uvicorn` não encontra o processo (para o sistema ele se chama `python3`), então o PID foi
obtido pelo próprio systemd.

```
$ systemctl status ufla-shop --no-pager | grep -E 'Active|Main PID'
     Active: active (running) since Sun 2026-10-11 22:39:54 -03; 9s ago
   Main PID: 79559 (uvicorn)
$ sudo kill -9 $(systemctl show -p MainPID --value ufla-shop)
$ sleep 5
$ systemctl status ufla-shop --no-pager
● ufla-shop.service - ufla-devops-shop (API FastAPI)
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-10-11 22:40:12 -03; 17s ago
   Main PID: 80149 (uvicorn)
      Tasks: 1 (limit: 34689)
     Memory: 42.1M (peak: 42.8M)
        CPU: 255ms
     CGroup: /system.slice/ufla-shop.service
             └─80149 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/…

out 11 22:40:12 caio-souza-yg-350 systemd[1]: ufla-shop.service: Scheduled r… 1.
out 11 22:40:12 caio-souza-yg-350 systemd[1]: Started ufla-shop.service - uf…I).
out 11 22:40:12 caio-souza-yg-350 uvicorn[80149]: INFO:     Started server p…49]
out 11 22:40:12 caio-souza-yg-350 uvicorn[80149]: INFO:     Waiting for appl…up.
out 11 22:40:12 caio-souza-yg-350 uvicorn[80149]: 2026-10-11 22:40:12,967 IN…50)
out 11 22:40:13 caio-souza-yg-350 uvicorn[80149]: 2026-10-11 22:40:13,005 IN…ql)
out 11 22:40:13 caio-souza-yg-350 uvicorn[80149]: INFO:     Application star…te.
out 11 22:40:13 caio-souza-yg-350 uvicorn[80149]: INFO:     Uvicorn running …it)
```

O PID mudou de 79559 para 80149 e o log mostra `Scheduled restart`: o `Restart=on-failure` subiu
o serviço de novo. O processo roda como o usuário de sistema, não como root:

```
$ ps -o user,pid,cmd -C uvicorn
USER         PID CMD
ufla-sh+   80149 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvico
```

## (c) `curl` no Nginx

```
$ curl -kI https://localhost
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Mon, 12 Oct 2026 01:40:54 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 1262
Connection: keep-alive
accept-ranges: bytes
last-modified: Mon, 12 Oct 2026 01:39:53 GMT
etag: "7eea432eb3b11e770baf5cc600acb69f"

$ curl -I http://localhost
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Date: Mon, 12 Oct 2026 01:41:02 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/
```

A API ouve só em `127.0.0.1` — de fora, só o Nginx:

```
$ ss -tlnp | grep 8000
LISTEN 0      2048            127.0.0.1:8000       0.0.0.0:*
```

A rota `/` da API só aceita `GET`, e o `curl -I` envia `HEAD`. Por isso o `loja.conf` repassa
`HEAD` como `GET` à API (`proxy_method`); o Nginx devolve só os cabeçalhos ao cliente.

## (d) `ls -la /var/backups/ufla-shop` depois de três backups

```
$ sudo systemctl start ufla-shop-backup.service; sleep 61
$ sudo systemctl start ufla-shop-backup.service; sleep 61
$ sudo systemctl start ufla-shop-backup.service
$ sudo ls -la /var/backups/ufla-shop
total 20
drwxr-x--- 2 ufla-shop ufla-shop 4096 out 11 22:43 .
drwxr-xr-x 3 root      root      4096 out 11 22:35 ..
-rw-r--r-- 1 ufla-shop ufla-shop 1629 out 11 22:41 loja-2026-10-11-2241.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1627 out 11 22:42 loja-2026-10-11-2242.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1629 out 11 22:43 loja-2026-10-11-2243.sql.gz
$ journalctl -t backup -n 3 --no-pager
out 11 22:41:26 caio-souza-yg-350 backup[80321]: backup gerado: /var/backups/ufla-shop/loja-2026-10-11-2241.sql.gz (4,0K)
out 11 22:42:30 caio-souza-yg-350 backup[80524]: backup gerado: /var/backups/ufla-shop/loja-2026-10-11-2242.sql.gz (4,0K)
out 11 22:43:35 caio-souza-yg-350 backup[80628]: backup gerado: /var/backups/ufla-shop/loja-2026-10-11-2243.sql.gz (4,0K)
```

O intervalo de 61 s entre as execuções é necessário porque o nome do arquivo vai até o minuto.

Timer diário instalado e ativo:

```
$ systemctl list-timers ufla-shop-backup.timer --no-pager
NEXT                    LEFT LAST PASSED UNIT                ACTIVATES
Mon 2026-10-12 03:… 4h 10min -         - ufla-shop-backup.t… ufla-shop-backup.s…

1 timers listed.
```

## (e) Idempotência: duas execuções seguidas do `deploy.sh`

```
$ sudo ./scripts/deploy.sh 2>&1 | tail -5
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
==> Healthcheck em http://localhost:8000/ready
OK: aplicacao no ar (tentativa 1)
$ sudo ./scripts/deploy.sh 2>&1 | tail -5
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
==> Healthcheck em http://localhost:8000/ready
OK: aplicacao no ar (tentativa 1)
$ systemctl status ufla-shop --no-pager | grep -E 'Active|Main PID'
     Active: active (running) since Sun 2026-10-11 22:49:03 -03; 2s ago
   Main PID: 83828 (uvicorn)
```

Cada passo do script ou verifica antes de criar (usuário, venv, `/etc/ufla-shop.env`, certificado)
ou refaz de forma segura (cópia do código, units, `restart`), então a segunda execução não quebra
nem duplica nada.

## Onde travei

O primeiro teste de Restart falhou com `address already in use`: o `uvicorn` iniciado à mão na
Parte 1.1 ainda ocupava a porta 8000. O systemd tentou 5 vezes e desistiu
(`Start request repeated too quickly`), mas o healthcheck do deploy passou mesmo assim, porque quem
respondia o `/ready` era o processo manual. Solução: encerrar o processo manual,
`sudo systemctl reset-failed ufla-shop` e rodar o deploy de novo.
