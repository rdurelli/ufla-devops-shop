# Atividade 3 — Bernardo Pavani (@BernardoPavani)

## (a) Como rodar o `deploy.sh` numa máquina limpa

Em uma máquina Ubuntu/Debian limpa, instale as dependências de sistema (Python venv, PostgreSQL, Redis e Nginx), configure o banco de dados inicial e execute o script de deploy:

```bash
# 1. Instalar dependências do sistema
sudo apt update
sudo apt install -y python3-venv postgresql redis-server nginx openssl curl

# 2. Garantir que PostgreSQL e Redis estão ativos e criar usuário/banco da aplicação
sudo systemctl enable --now postgresql redis-server
sudo -u postgres psql -c "CREATE USER loja WITH PASSWORD 'troque-esta-senha';"
sudo -u postgres psql -c "CREATE DATABASE loja OWNER loja;"

# 3. Executar o script de deploy idempotente
chmod +x scripts/deploy.sh scripts/backup.sh
./scripts/deploy.sh
```

*(Caso a senha do banco seja alterada em produção, basta editá-la em `/etc/ufla-shop.env` e reiniciar o serviço com `sudo systemctl restart ufla-shop`).*

---

## (b) Saída de `systemctl status ufla-shop` depois do `kill -9`

Antes do `kill -9`, o serviço rodava sob o `Main PID: 124058`. Após executar `sudo kill -9 $(pidof -x uvicorn || pgrep -f uvicorn)` e aguardar 5 segundos, o `systemd` reiniciou automaticamente o processo (`Restart=on-failure`) com um novo PID (`124499`):

```text
● ufla-shop.service - UFLA DevOps Shop API
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2026-09-28 15:43:16 -03; 19s ago
   Main PID: 124499 (uvicorn)
      Tasks: 1 (limit: 18644)
     Memory: 39.1M
        CPU: 384ms
     CGroup: /system.slice/ufla-shop.service
             └─124499 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --port 8000

set 28 15:43:16 ubunto-berna systemd[1]: Started UFLA DevOps Shop API.
set 28 15:43:16 ubunto-berna uvicorn[124499]: INFO:     Started server process [124499]
set 28 15:43:16 ubunto-berna uvicorn[124499]: INFO:     Waiting for application startup.
set 28 15:43:16 ubunto-berna uvicorn[124499]: 2026-09-28 15:43:16,823 INFO loja: ufla-devops-shop 1.0.0 subindo (banco=postgresql…to-berna)
set 28 15:43:16 ubunto-berna uvicorn[124499]: 2026-09-28 15:43:16,871 INFO loja.banco: banco pronto (modo postgresql)
set 28 15:43:16 ubunto-berna uvicorn[124499]: INFO:     Application startup complete.
set 28 15:43:16 ubunto-berna uvicorn[124499]: INFO:     Uvicorn running on [http://127.0.0.1:8000](http://127.0.0.1:8000) (Press CTRL+C to quit)
```

---

## (c) Saída de `curl -kI https://localhost` e de `curl -I http://localhost`

```text
$ curl -kI https://localhost
HTTP/2 200 
server: nginx/1.18.0 (Ubuntu)
date: Mon, 28 Sep 2026 20:09:51 GMT
content-type: text/html; charset=utf-8
content-length: 1262
accept-ranges: bytes
last-modified: Mon, 28 Sep 2026 20:09:46 GMT
etag: "994a5f9bb02dcd9058138d0d29c6c1af"

$ curl -I http://localhost
HTTP/1.1 301 Moved Permanently
Server: nginx/1.18.0 (Ubuntu)
Date: Mon, 28 Sep 2026 20:09:51 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/
```

---

## (d) Saída de `ls -la /var/backups/ufla-shop` depois de rodar o backup três vezes

```text
$ ls -la /var/backups/ufla-shop
total 20
drwxr-xr-x 2 ufla-shop ufla-shop 4096 set 28 17:07 .
drwxr-xr-x 3 root      root      4096 set 28 15:34 ..
-rw-r--r-- 1 ufla-shop ufla-shop 1624 set 28 17:07 loja-2026-09-28-170743.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1623 set 28 17:07 loja-2026-09-28-170745.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1625 set 28 17:07 loja-2026-09-28-1707.sql.gz
```

Status do timer ativo no `systemd`:
```text
$ systemctl list-timers ufla-shop-backup.timer --no-pager
NEXT                        LEFT    LAST PASSED UNIT                   ACTIVATES               
Tue 2026-09-29 03:00:00 -03 9h left n/a  n/a    ufla-shop-backup.timer ufla-shop-backup.service

1 timers listed.
```

---

## (e) Prova da idempotência: duas execuções seguidas do `deploy.sh`

```text
$ ./scripts/deploy.sh && ./scripts/deploy.sh
==> [1/7] A verificar utilizador de sistema ufla-shop...
==> [2/7] A preparar ficheiro de ambiente (/etc/ufla-shop.env)...
==> [3/7] A preparar diretorio de backups (/var/backups/ufla-shop)...
==> [4/7] A sincronizar codigo para /opt/ufla-shop e instalar dependencias...
==> [5/7] A configurar certificado TLS e Nginx...
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable nginx
==> [6/7] A instalar e iniciar units do systemd...
==> [7/7] A executar healthcheck em http://localhost:8000/ready...
Tentativa 1/10: status 000. A aguardar 1s...
Healthcheck OK (HTTP 200) na tentativa 2!
==> [1/7] A verificar utilizador de sistema ufla-shop...
==> [2/7] A preparar ficheiro de ambiente (/etc/ufla-shop.env)...
==> [3/7] A preparar diretorio de backups (/var/backups/ufla-shop)...
==> [4/7] A sincronizar codigo para /opt/ufla-shop e instalar dependencias...
==> [5/7] A configurar certificado TLS e Nginx...
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable nginx
==> [6/7] A instalar e iniciar units do systemd...
==> [7/7] A executar healthcheck em http://localhost:8000/ready...
Tentativa 1/10: status 000. A aguardar 1s...
Healthcheck OK (HTTP 200) na tentativa 2!
```