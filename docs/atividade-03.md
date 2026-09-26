# Atividade 3 - Automatizar de verdade

## Pré-requisitos e configuração

O ambiente precisa de Linux com systemd ativo, PostgreSQL e Redis locais. No WSL2, systemd deve estar habilitado em /etc/wsl.conf. Crie o usuário loja e o banco loja conforme a Parte 1.1.

Antes do primeiro deploy, copie o modelo para o arquivo protegido e edite DATABASE_URL para usar a senha real e a porta do PostgreSQL local. Não versione nem cole o conteúdo de /etc/ufla-shop.env.

~~~bash
sudo install -o root -g root -m 0600 ufla-shop.env.example /etc/ufla-shop.env
sudoedit /etc/ufla-shop.env
~~~

Neste WSL, o cluster PostgreSQL local escuta na porta 5433; o valor de DATABASE_URL em /etc/ufla-shop.env foi ajustado para essa porta. Em uma máquina limpa, use a porta mostrada por pg_lsclusters. O exemplo versionado mantém CHANGE_ME como placeholder.

O deploy instala /etc/ufla-shop.env.example e só cria /etc/ufla-shop.env se ele não existir. Nas execuções seguintes, preserva o arquivo existente.

## Deploy

Execute da raiz do repositório, depois de configurar /etc/ufla-shop.env:

~~~bash
sudo bash scripts/deploy.sh
~~~

O script verifica systemd, prepara dependências ausentes, cria o usuário ufla-shop, sincroniza o código em /opt/ufla-shop, instala requirements.txt no venv, configura as units e o Nginx, gera o certificado autoassinado fora do repositório e termina verificando /ready.

## Evidências

### Reinício automático do serviço

Com o serviço no ar, mate o processo Uvicorn e consulte o estado cinco segundos depois:

~~~bash
sudo kill -9 "$(pidof uvicorn)"
sleep 5
systemctl status ufla-shop --no-pager
~~~

Saída capturada:

~~~text
● ufla-shop.service - API ufla-devops-shop
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-09-23 21:08:04 -03; 3s ago
   Main PID: 12155 (uvicorn)
      Tasks: 1 (limit: 9494)
     Memory: 41.9M ()
     CGroup: /system.slice/ufla-shop.service
             └─12155 /opt/ufla-shop/.venv/bin/python /opt/ufla-shop/.venv/bin/uvicorn app:api --host 127.0.0.1 --port 8000

Sep 23 21:08:04 DESKTOP-4G08ML3 systemd[1]: ufla-shop.service: Scheduled restart job, restart counter is at 1.
Sep 23 21:08:04 DESKTOP-4G08ML3 systemd[1]: Started ufla-shop.service - API ufla-devops-shop.
Sep 23 21:08:05 DESKTOP-4G08ML3 uvicorn[12155]: INFO:     Started server process [12155]
Sep 23 21:08:05 DESKTOP-4G08ML3 uvicorn[12155]: INFO:     Waiting for application startup.
Sep 23 21:08:05 DESKTOP-4G08ML3 uvicorn[12155]: 2026-09-23 21:08:05,041 INFO loja: ufla-devops-shop 1.0.0 subindo (banco=postgresql, cache=redis, instancia=DESKTOP-4G08ML3)
Sep 23 21:08:05 DESKTOP-4G08ML3 uvicorn[12155]: 2026-09-23 21:08:05,123 INFO loja.banco: banco pronto (modo postgresql)
Sep 23 21:08:05 DESKTOP-4G08ML3 uvicorn[12155]: INFO:     Application startup complete.
Sep 23 21:08:05 DESKTOP-4G08ML3 uvicorn[12155]: INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
~~~

### Nginx: HTTPS e redirecionamento

~~~bash
curl -kI https://localhost
curl -I http://localhost
~~~

Saídas capturadas:

~~~text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 24 Sep 2026 00:09:21 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 1262
Connection: keep-alive
accept-ranges: bytes
last-modified: Wed, 23 Sep 2026 21:55:39 GMT
etag: "ab13c010a5d4665563284537e9baa04d"
~~~

~~~text
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 24 Sep 2026 00:09:21 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/
~~~

### Três backups

Inicie o serviço de backup três vezes. Como o nome exigido tem precisão de minuto, o script espera a virada do minuto se já existir um arquivo com o mesmo nome, evitando sobrescrevê-lo.

~~~bash
sudo systemctl start ufla-shop-backup.service
sudo systemctl start ufla-shop-backup.service
sudo systemctl start ufla-shop-backup.service
ls -la /var/backups/ufla-shop
~~~

Saída capturada:

~~~text
total 20
drwxr-x--- 2 ufla-shop ufla-shop 4096 Sep 23 21:11 .
drwxr-xr-x 3 root      root      4096 Sep 23 21:06 ..
-rw------- 1 ufla-shop ufla-shop 1592 Sep 23 21:09 loja-2026-09-23-2109.sql.gz
-rw------- 1 ufla-shop ufla-shop 1589 Sep 23 21:10 loja-2026-09-23-2110.sql.gz
-rw------- 1 ufla-shop ufla-shop 1589 Sep 23 21:11 loja-2026-09-23-2111.sql.gz
~~~

### Idempotência do deploy

Execute duas vezes seguidas. As duas execuções terminaram com healthcheck HTTP 200:

~~~bash
sudo bash scripts/deploy.sh
sudo bash scripts/deploy.sh
~~~

Saídas finais capturadas:

~~~text
--- DEPLOY 1 ---
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
Healthcheck OK: HTTP 200 na tentativa 1/10.

--- DEPLOY 2 ---
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
Healthcheck OK: HTTP 200 na tentativa 1/10.
~~~

### Timer ativo

~~~bash
systemctl list-timers ufla-shop-backup.timer --no-pager
~~~

Saída capturada:

~~~text
NEXT                            LEFT LAST PASSED UNIT                   ACTIVATES
Thu 2026-09-24 03:00:00 -03 5h 47min -         - ufla-shop-backup.timer ufla-shop-backup.service

1 timers listed.
~~~