# Atividade 03 — Automatizar de verdade

## Execução do deploy

Para executar o deploy em uma máquina Linux:

```bash
sudo ./scripts/deploy.sh
```

O script instala as dependências necessárias, configura a aplicação em `/opt/ufla-shop`, instala os serviços do systemd, configura o Nginx com TLS e realiza um healthcheck ao final.

## Restart automático do serviço

Foi encerrado manualmente o processo principal da aplicação com:

```bash
sudo kill -9 "$(systemctl show -p MainPID --value ufla-shop)"
sleep 5
systemctl status ufla-shop --no-pager
```

Após o encerramento, o systemd reiniciou automaticamente o serviço:

```text
● ufla-shop.service - UFLA Shop
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-09-27 23:04:06 -03
   Main PID: 31714 (uvicorn)

set 27 23:04:06 acer-aspire-5 systemd[1]: ufla-shop.service: Scheduled restart job, restart counter is at 1.
set 27 23:04:06 acer-aspire-5 systemd[1]: Started ufla-shop.service - UFLA Shop.
set 27 23:04:06 acer-aspire-5 uvicorn[31714]: INFO: Started server process [31714]
set 27 23:04:06 acer-aspire-5 uvicorn[31714]: INFO: Application startup complete.
set 27 23:04:06 acer-aspire-5 uvicorn[31714]: INFO: Uvicorn running on http://127.0.0.1:8000
```

## Nginx e TLS

### HTTP

Comando:

```bash
curl -I http://localhost
```

Saída:

```text
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Location: https://localhost/
```

O acesso HTTP é redirecionado para HTTPS.

### HTTPS

Comando:

```bash
curl -kI https://localhost
```

Saída:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: application/octet-stream
Content-Length: 0
Connection: keep-alive
```

## Backup

O script de backup foi executado três vezes.

Comando de verificação:

```bash
ls -la /var/backups/ufla-shop
```

Saída:

```text
total 24
drwxr-xr-x 2 root root 4096 set 27 23:00 .
drwxr-xr-x 3 root root 4096 set 27 23:03 ..
-rw-r--r-- 1 root root 1620 set 27 23:00 loja-2026-09-27-230019.sql.gz
-rw-r--r-- 1 root root 1623 set 27 23:00 loja-2026-09-27-230021.sql.gz
-rw-r--r-- 1 root root 1623 set 27 23:00 loja-2026-09-27-230023.sql.gz
```

## Idempotência

O script `deploy.sh` foi executado novamente após a instalação inicial.

Na segunda execução, os recursos já existentes foram reutilizados sem duplicação e o processo foi concluído normalmente:

```text
==> Criando usuario da aplicacao...
==> Copiando aplicacao...
==> Criando ambiente virtual...
==> Instalando dependencias Python...
Requirement already satisfied: fastapi==0.141.1
Requirement already satisfied: uvicorn==0.53.0
Requirement already satisfied: psycopg==3.3.6
Requirement already satisfied: redis==8.1.0
==> Configurando variaveis de ambiente...
==> Instalando arquivos do systemd...
==> Configurando Nginx...
==> Gerando certificado TLS...
==> Recarregando systemd...
==> Reiniciando Nginx...
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
==> Healthcheck...
Aplicacao pronta!
```

A execução repetida não criou novamente o usuário da aplicação, preservou o ambiente existente e terminou com o healthcheck respondendo com sucesso.