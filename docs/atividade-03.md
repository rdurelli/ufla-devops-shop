# Atividade 3 - Automatizar de verdade - DevOps

Jhuan Carlos Sabaini Dassie

---

## Como rodar o `deploy.sh` numa máquina limpa

Numa máquina limpa (Ubuntu/Debian ou Arch/Fedora), execute os passos abaixo:

1. **Instalar os serviços e ferramentas do sistema**:
   - No Ubuntu/Debian:
     ```bash
     sudo apt update && sudo apt install -y python3-venv postgresql redis-server nginx openssl curl
     ```
   - No Arch Linux:
     ```bash
     sudo pacman -Syu --noconfirm python postgresql redis nginx openssl curl
     ```

2. **Iniciar e configurar os bancos de dados**:

   ```bash
   sudo systemctl start postgresql redis
   sudo -u postgres psql -c "CREATE USER loja WITH PASSWORD 'troque-esta-senha';"
   sudo -u postgres psql -c "CREATE DATABASE loja OWNER loja;"
   ```

3. **Clonar o repositório e executar o deploy**:
   ```bash
   git clone <URL_DO_FORK> ufla-devops-shop
   cd ufla-devops-shop
   git switch atividade-03
   sudo ./scripts/deploy.sh
   ```

O script criará o usuário de sistema `ufla-shop`, copiará o código para `/opt/ufla-shop`, configurará o virtualenv, criará `/etc/ufla-shop.env` a partir do exemplo, gerará os certificados TLS autoassinados, configurará o Nginx e as units do systemd, e fará o healthcheck final.

## Saídas

### `systemctl status ufla-shop`

```sh
❯ systemctl status ufla-shop
● ufla-shop.service - UFLA DevOpsShop
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: disabled)
     Active: active (running) since Sat 2026-09-26 17:17:39 -03; 42s ago
 Invocation: 182a86b06e674e1785314c5727d35097
   Main PID: 64206 (uvicorn)
      Tasks: 2 (limit: 18149)
     Memory: 50.5M (peak: 51.9M)
        CPU: 525ms
     CGroup: /system.slice/ufla-shop.service
             └─64206 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --port 80>

set 26 17:17:39 metaknight systemd[1]: Started UFLA DevOpsShop.
set 26 17:17:40 metaknight uvicorn[64206]: INFO:     Started server process [64206]
set 26 17:17:40 metaknight uvicorn[64206]: INFO:     Waiting for application startup.
set 26 17:17:40 metaknight uvicorn[64206]: 2026-09-26 17:17:40,329 INFO loja: ufla-devops-shop 1.0.0 sub>
set 26 17:17:40 metaknight uvicorn[64206]: 2026-09-26 17:17:40,393 INFO loja.banco: banco pronto (modo p>
set 26 17:17:40 metaknight uvicorn[64206]: INFO:     Application startup complete.
set 26 17:17:40 metaknight uvicorn[64206]: INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTR>
set 26 17:17:41 metaknight uvicorn[64206]: INFO:     127.0.0.1:43964 - "GET /ready HTTP/1.1" 200 OK
```

### `kill -9`

```sh
❯ sudo kill -9 66683

❯ sudo sleep 5

❯ sudo kill -9 64206
● ufla-shop.service - UFLA DevOpsShop
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: disabled)
     Active: active (running) since Sat 2026-09-26 17:23:20 -03; 1min 33s ago
 Invocation: c46fffe78ab5462597b6a9d114380f2c
   Main PID: 66683 (uvicorn)
      Tasks: 1 (limit: 18149)
     Memory: 57.7M (peak: 58.7M)
        CPU: 594ms
     CGroup: /system.slice/ufla-shop.service
             └─66683 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --port 80>

set 26 17:23:20 metaknight systemd[1]: ufla-shop.service: Failed with result 'signal'.
set 26 17:23:20 metaknight systemd[1]: ufla-shop.service: Scheduled restart job, restart counter is at 1.
set 26 17:23:20 metaknight systemd[1]: Started UFLA DevOpsShop.
set 26 17:23:21 metaknight uvicorn[66683]: INFO:     Started server process [66683]
set 26 17:23:21 metaknight uvicorn[66683]: INFO:     Waiting for application startup.
set 26 17:23:21 metaknight uvicorn[66683]: 2026-09-26 17:23:21,261 INFO loja: ufla-devops-shop 1.0.0 sub>
set 26 17:23:21 metaknight uvicorn[66683]: 2026-09-26 17:23:21,333 INFO loja.banco: banco pronto (modo p>
set 26 17:23:21 metaknight uvicorn[66683]: INFO:     Application startup complete.
set 26 17:23:21 metaknight uvicorn[66683]: INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTR>

```

### `curl -kI https://localhost`

```sh
❯ curl -kI https://localhost
HTTP/1.1 200 OK
Server: nginx/1.30.4
Date: Sat, 26 Sep 2026 20:39:21 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 1262
Connection: keep-alive
accept-ranges: bytes
last-modified: Sat, 26 Sep 2026 20:38:19 GMT
etag: "910d3642c55febf8e9f54f2c95aa60be"
```

### `curl -I http://localhost`

```sh
❯ curl -I http://localhost
HTTP/1.1 301 Moved Permanently
Server: nginx/1.30.4
Date: Sat, 26 Sep 2026 20:19:40 GMT
Content-Type: text/html
Content-Length: 169
Connection: keep-alive
Location: https://localhost/
```

### `ls -la /var/backups/ufla-shop`

```sh
❯ ls -la /var/backups/ufla-shop
total 12
drwxr-xr-x 1 root root  162 set 26 17:43 .
drwxr-xr-x 1 root root   18 set 26 17:08 ..
-rw-r--r-- 1 root root 1606 set 26 17:41 loja-2026-09-26-1741.sql.gz
-rw-r--r-- 1 root root 1604 set 26 17:42 loja-2026-09-26-1742.sql.gz
-rw-r--r-- 1 root root 1605 set 26 17:43 loja-2026-09-26-1743.sql.gz
```

## Prova de idempotência

```sh
❯ sudo ./scripts/deploy.sh 2>&1 | tail -3
Executando Healthcheck ❤...
Tentativa 1 de 10 falhou. Aguardando 1s...
RES = 200 | OK! Aplicação pronta.
❯ sudo ./scripts/deploy.sh 2>&1 | tail -3
Executando Healthcheck ❤...
Tentativa 1 de 10 falhou. Aguardando 1s...
RES = 200 | OK! Aplicação pronta.
```
