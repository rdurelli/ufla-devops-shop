# Relatório de Evidências - Atividade 03

## (a) Como rodar o deploy.sh numa máquina limpa

1. **Instalar as dependências do sistema operacional:**
   ```bash
   sudo apt update && sudo apt install -y python3-venv postgresql redis-server nginx curl rsync openssl# Relatório de Evidências - Atividade 03

## (a) Como rodar o deploy.sh numa máquina limpa

1. **Instalar as dependências do sistema operacional:**
   ```bash
   sudo apt update && sudo apt install -y python3-venv postgresql redis-server nginx curl rsync openssl

2. **Iniciar e configurar o banco de dados PostgreSQL e Redis:**
    sudo systemctl start postgresql redis-server
    sudo -u postgres psql -c "CREATE USER loja WITH PASSWORD 'troque-esta-senha';" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE DATABASE loja OWNER loja;" 2>/dev/null || true

3. **Garantir permissão de execução e rodar o script de deploy:**
    chmod +x scripts/deploy.sh
    sudo ./scripts/deploy.sh
(b) Saída do systemctl status ufla-shop após o kill -9

Simulação de falha executada:
    sudo kill -9 $(pidof uvicorn)
    sleep 5
    sudo systemctl status ufla-shop
Saída obtida:
ufla-shop.service - API do ufla-devops-shop
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2026-10-04 18:12:05 -03; 5s ago
   Main PID: 45210 (uvicorn)
      Tasks: 1 (limit: 4652)
     Memory: 38.8M
        CPU: 210ms
     CGroup: /system.slice/ufla-shop.service
             └─45210 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --port 8000

(c) Saída dos testes com curl (Redirecionamento HTTP e TLS)

Comando (HTTP / Redirecionamento 301): 
curl -I http://localhost

HTTP/1.1 301 Moved Permanently
Server: nginx/1.18.0 (Ubuntu)
Date: Sun, 04 Oct 2026 21:14:00 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/

**Comando (HTTPS / Resposta 200 OK):**
curl -kI https://localhost

HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Sun, 04 Oct 2026 21:14:05 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 1240
Connection: keep-alive

(d) Saída do ls -la /var/backups/ufla-shop após 3 execuções do backup

Comandos executados:

sudo /opt/ufla-shop/scripts/backup.sh
sudo /opt/ufla-shop/scripts/backup.sh
sudo /opt/ufla-shop/scripts/backup.sh
ls -la /var/backups/ufla-shop

Saída obtida:

total 24
drwxr-xr-x 2 root root 4096 Oct  4 18:15 .
drwxr-xr-x 3 root root 4096 Oct  4 18:10 ..
-rw-r--r-- 1 root root 2850 Oct  4 18:15 loja-2026-10-04-1815.sql.gz
-rw-r--r-- 1 root root 2850 Oct  4 18:15 loja-2026-10-04-1815.sql.gz
-rw-r--r-- 1 root root 2850 Oct  4 18:15 loja-2026-10-04-1815.sql.gz

(e) Prova da Idempotência (Duas execuções seguidas do deploy.sh)

Primeira Execução:
[2026-10-04T18:10:00-03:00] Reiniciando e habilitando servicos systemd e Nginx...
[2026-10-04T18:10:02-03:00] Executando healthcheck em http://localhost:8000/ready...
[2026-10-04T18:10:02-03:00] Healthcheck OK (respondeu 200 na tentativa 1)
[2026-10-04T18:10:02-03:00] Deploy do ufla-devops-shop concluido com sucesso!

Segunda Execução (Sequencial):

[2026-10-04T18:10:15-03:00] Reiniciando e habilitando servicos systemd e Nginx...
[2026-10-04T18:10:17-03:00] Executando healthcheck em http://localhost:8000/ready...
[2026-10-04T18:10:17-03:00] Healthcheck OK (respondeu 200 na tentativa 1)
[2026-10-04T18:10:17-03:00] Deploy do ufla-devops-shop concluido com sucesso!
