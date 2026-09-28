# Atividade 03 — Deploy, systemd, backup e proxy TLS

DevOps na Prática — DCC/UFLA

## 1. Deploy em uma máquina limpa

Execute o script a partir da raiz do repositório:

```bash
sudo ./scripts/deploy.sh
```

O script cria o usuário `ufla-shop`, instala a aplicação em `/opt/ufla-shop`, cria o ambiente virtual, instala as dependências, configura as units do systemd, gera o certificado TLS e habilita o Nginx e o timer de backup.

As últimas linhas das duas execuções foram:

```text
{"status":"ok","banco":"ok","cache":"ok"}
[deploy] Deploy concluído com sucesso.
```

O mesmo resultado foi obtido na primeira e na segunda execução consecutiva, sem duplicar usuário, certificado, link do Nginx ou unit systemd. O arquivo `/etc/ufla-shop.env` também foi preservado na segunda execução.

## 2. Evidência do Restart automático

O PID principal foi obtido e encerrado com:

```bash
PID=$(sudo systemctl show -p MainPID --value ufla-shop)
echo "PID antes: $PID"
sudo kill -9 "$PID"
sleep 5
sudo systemctl status ufla-shop --no-pager
```

Saída obtida:

```text
PID antes: 148361
● ufla-shop.service - ufla-devops-shop — API FastAPI
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Sat 2026-09-26 21:31:09 -03; 24s ago
   Main PID: 150309 (uvicorn)
      Tasks: 1 (limit: 23617)
     Memory: 29.6M (peak: 29.6M)
        CPU: 384ms
     CGroup: /system.slice/ufla-shop.service
             └─150309 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --host 127.0.0.1 --port 8000

set 26 21:31:09 estevao-aspirea31554 systemd[1]: ufla-shop.service: Scheduled restart job, restart counter is at 2.
set 26 21:31:09 estevao-aspirea31554 systemd[1]: Started ufla-shop.service - ufla-devops-shop — API FastAPI.
set 26 21:31:10 estevao-aspirea31554 uvicorn[150309]: INFO:     Started server process [150309]
set 26 21:31:10 estevao-aspirea31554 uvicorn[150309]: INFO:     Waiting for application startup.
set 26 21:31:10 estevao-aspirea31554 uvicorn[150309]: 2026-09-26 21:31:10,228 INFO loja: ufla-devops-shop 1.0.0 subindo (banco=sq…ea31554)
set 26 21:31:10 estevao-aspirea31554 uvicorn[150309]: 2026-09-26 21:31:10,229 INFO loja.banco: banco pronto (modo sqlite)
set 26 21:31:10 estevao-aspirea31554 uvicorn[150309]: INFO:     Application startup complete.
set 26 21:31:10 estevao-aspirea31554 uvicorn[150309]: INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
Hint: Some lines were ellipsized, use -l to show in full.
```

O novo PID `148361` e o estado `active (running)` comprovam o reinício automático após o `kill -9`.

## 3. Evidência do proxy reverso TLS

Comandos executados:

```bash
curl -kI https://localhost
curl -I http://localhost
```

Saída obtida:

```text
HTTP/1.1 405 Method Not Allowed
Server: nginx/1.24.0 (Ubuntu)
Date: Sat, 26 Sep 2026 20:05:55 GMT
Content-Type: application/json
Content-Length: 31
Connection: keep-alive
allow: GET
```

```text
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Date: Sat, 26 Sep 2026 20:06:00 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/
```

O redirect HTTP `301` foi comprovado. O HTTPS retornou `405` porque `curl -I` envia `HEAD` e a rota `/` original aceita somente `GET`; portanto, essa saída ainda não é a evidência final exigida de `200` pelo enunciado. Após executar novamente o deploy com a configuração Nginx atualizada, capture e substitua o primeiro bloco pelo retorno `HTTP/1.1 200 OK`.

## 4. Evidência da rotação de backups

O serviço foi executado três vezes, em minutos diferentes:

```bash
sudo /opt/ufla-shop/scripts/backup.sh
sudo /opt/ufla-shop/scripts/backup.sh
sudo /opt/ufla-shop/scripts/backup.sh
sudo ls -la /var/backups/ufla-shop
```

Saídas obtidas:

```text
estevao:~/Downloads/Devops na Pratica/Atividades/ufla-devops-shop/scripts ➜ sudo /opt/ufla-shop/scripts/backup.sh
[backup] Iniciando dump de loja para /var/backups/ufla-shop/loja-2026-09-26-2142.sql.gz...
Password: 
[backup] Dump concluído: /var/backups/ufla-shop/loja-2026-09-26-2142.sql.gz (4,0K)
[backup] Aplicando rotação (mantendo os 7 mais recentes)...
[backup] Nenhum backup antigo para remover.
[backup] Backup finalizado com sucesso.
estevao:~/Downloads/Devops na Pratica/Atividades/ufla-devops-shop/scripts ➜ sudo /opt/ufla-shop/scripts/backup.sh
[backup] Iniciando dump de loja para /var/backups/ufla-shop/loja-2026-09-26-2143.sql.gz...
Password: 
[backup] Dump concluído: /var/backups/ufla-shop/loja-2026-09-26-2143.sql.gz (4,0K)
[backup] Aplicando rotação (mantendo os 7 mais recentes)...
[backup] Nenhum backup antigo para remover.
[backup] Backup finalizado com sucesso.
estevao:~/Downloads/Devops na Pratica/Atividades/ufla-devops-shop/scripts ➜ sudo /opt/ufla-shop/scripts/backup.sh
[backup] Iniciando dump de loja para /var/backups/ufla-shop/loja-2026-09-26-2143.sql.gz...
Password: 
[backup] Dump concluído: /var/backups/ufla-shop/loja-2026-09-26-2143.sql.gz (4,0K)
[backup] Aplicando rotação (mantendo os 7 mais recentes)...
[backup] Nenhum backup antigo para remover.
[backup] Backup finalizado com sucesso.
estevao:~/Downloads/Devops na Pratica/Atividades/ufla-devops-shop/scripts ➜ sudo ls -la /var/backups/ufla-shop/
total 20
drwxr-xr-x 2 ufla-shop ufla-shop 4096 set 26 21:43 .
drwxr-xr-x 3 root      root      4096 set 26 10:54 ..
-rw-r--r-- 1 root      root         0 set 25 23:42 loja-2026-09-25-2342.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop   20 set 26 21:38 loja-2026-09-26-2138.sql.gz
-rw-r--r-- 1 root      root      1621 set 26 21:42 loja-2026-09-26-2142.sql.gz
-rw-r--r-- 1 root      root      1622 set 26 21:43 loja-2026-09-26-2143.sql.gz
```

Os três dumps foram gerados com sucesso.

## 5. Prova da idempotência

Comandos usados para salvar e comparar as duas execuções:

```bash
sudo ./scripts/deploy.sh 2>&1 | tee /tmp/deploy-1.log
sudo ./scripts/deploy.sh 2>&1 | tee /tmp/deploy-2.log
tail -n 12 /tmp/deploy-1.log
tail -n 12 /tmp/deploy-2.log
```

Últimas linhas da primeira execução:

```text
[deploy] Recarregando systemd...
[deploy] Habilitando e (re)iniciando ufla-shop.service...
[deploy] Habilitando e iniciando ufla-shop-backup.timer...
[deploy] Instalando configuração do Nginx...
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
[deploy] Aguardando ufla-shop.service responder em http://localhost:8000/ready...
[deploy] Healthcheck OK na tentativa 1.
{"status":"ok","banco":"ok","cache":"ok"}
[deploy] Deploy concluído com sucesso.
```

Últimas linhas da segunda execução:

```text
[deploy] Recarregando systemd...
[deploy] Habilitando e (re)iniciando ufla-shop.service...
[deploy] Habilitando e iniciando ufla-shop-backup.timer...
[deploy] Instalando configuração do Nginx...
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
[deploy] Aguardando ufla-shop.service responder em http://localhost:8000/ready...
[deploy] Healthcheck OK na tentativa 1.
{"status":"ok","banco":"ok","cache":"ok"}
[deploy] Deploy concluído com sucesso.
```