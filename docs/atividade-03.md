# Atividade 03 — deploy, systemd, Nginx e backup

Nesta atividade configurei o deploy da aplicação como um serviço do systemd,
coloquei o Nginx como proxy reverso com HTTPS e criei um backup diário do
PostgreSQL.

## Deploy em uma máquina limpa

Considerei uma máquina limpa em relação à aplicação. O PostgreSQL já precisa
ter o banco `loja` e o usuário configurados, pois a senha fica fora do script.
As ferramentas usadas no deploy são instaladas pelo próprio `deploy.sh`.

Primeiro, clonei o repositório e entrei na branch da atividade:

```bash
git clone git@github.com:PauloHSilveir/ufla-devops-shop.git
cd ufla-devops-shop
git switch atividade-03
```

Depois, executei o deploy como root:

```bash
sudo ./scripts/deploy.sh
```

Na primeira execução, o script cria `/etc/ufla-shop.env.example` e copia esse
modelo para `/etc/ufla-shop.env`. Como a senha não pode ficar no repositório, o
script para nesse ponto para que ela seja configurada:

```bash
sudo nano /etc/ufla-shop.env
sudo ./scripts/deploy.sh
```

O segundo comando sincroniza o projeto em `/opt/ufla-shop`, cria o ambiente
virtual, instala as units do systemd, configura o Nginx e termina fazendo o
healthcheck em `http://localhost:8000/ready`.

## Reinício automático do serviço

Usei os comandos abaixo para encerrar o Uvicorn e verificar o serviço cinco
segundos depois:

```bash
sudo kill -9 $(pidof uvicorn)
sleep 5
systemctl status ufla-shop --no-pager
```

O serviço estava de pé novamente:

```text
● ufla-shop.service - UFLa Shop API
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-10-07 23:03:25 -03
   Main PID: 10462 (uvicorn)
      Tasks: 2
     CGroup: /system.slice/ufla-shop.service
             └─10462 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --host 127.0.0.1 --port 8000
```

Também conferi no journal que a causa foi o `kill -9` e que o systemd reiniciou
o processo dois segundos depois:

```text
2026-10-07T23:03:23-03:00 MX-34 systemd[1]: ufla-shop.service: Main process exited, code=killed, status=9/KILL
2026-10-07T23:03:23-03:00 MX-34 systemd[1]: ufla-shop.service: Failed with result 'signal'.
2026-10-07T23:03:25-03:00 MX-34 systemd[1]: ufla-shop.service: Scheduled restart job, restart counter is at 1.
2026-10-07T23:03:25-03:00 MX-34 systemd[1]: Started ufla-shop.service - UFLa Shop API.
2026-10-07T23:03:25-03:00 MX-34 uvicorn[10462]: INFO:     Started server process [10462]
```

## Teste do Nginx

Com HTTPS, a requisição chega à aplicação e retorna 200:

```console
$ curl -kI https://localhost
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html; charset=utf-8
Content-Length: 1262
Connection: keep-alive
```

No HTTP, o Nginx redireciona para HTTPS:

```console
$ curl -I http://localhost
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/
```

A porta 8000 fica disponível somente em `127.0.0.1`; as conexões externas
passam pelas portas 80 e 443 do Nginx.

## Backup e rotação

Executei o serviço de backup em três momentos diferentes:

```bash
sudo systemctl start ufla-shop-backup.service
ls -la /var/backups/ufla-shop
```

Resultado:

```text
total 20
drwxr-xr-x 2 root root 4096 Oct  8 00:57 .
drwxr-xr-x 3 root root 4096 Oct  7 23:13 ..
-rw-r--r-- 1 root root 1624 Oct  7 23:41 loja-2026-10-07-2341.sql.gz
-rw-r--r-- 1 root root 1619 Oct  8 00:54 loja-2026-10-08-0054.sql.gz
-rw-r--r-- 1 root root 1620 Oct  8 00:57 loja-2026-10-08-0057.sql.gz
```

O nome possui data e hora, e o script mantém somente os sete arquivos mais
recentes. Como ele usa `set -o pipefail`, uma falha no `pg_dump` também faz o
serviço de backup falhar. O arquivo incompleto é removido pelo `trap`.

## Teste de idempotência

Por fim, rodei o deploy duas vezes seguidas. Estas foram as últimas linhas da
primeira execução:

```text
nginx: configuration file /etc/nginx/nginx.conf test is successful
==> Aguardando aplicacao responder em /ready
Healthcheck OK: HTTP 200
==> Deploy concluido com sucesso.
```

E estas foram as últimas linhas da segunda execução:

```text
nginx: configuration file /etc/nginx/nginx.conf test is successful
==> Aguardando aplicacao responder em /ready
Healthcheck OK: HTTP 200
==> Deploy concluido com sucesso.
```

A segunda execução reaproveitou o usuário, o arquivo de configuração e o
certificado já existentes. Nenhum serviço ou arquivo foi duplicado.
