# Atividade 03 - Automatizar de Verdade

Esta documentação contém as evidências da implementação da infraestrutura de deploy da aplicação UFLA DevOps Shop.

## 1. Como rodar o deploy.sh numa máquina limpa

Para instalar a aplicação em uma máquina Ubuntu/Debian limpa, siga os passos:

1. Instale as dependências básicas:
   ```bash
   sudo apt update
   sudo apt install -y python3-venv postgresql redis-server nginx rsync openssl
   ```
2. Configure o banco de dados:
   ```bash
   sudo -u postgres psql -c "CREATE USER loja WITH PASSWORD 'troque-esta-senha';"
   sudo -u postgres psql -c "CREATE DATABASE loja OWNER loja;"
   ```
3. Clone o repositório e execute o script de deploy:
   ```bash
   git clone <url-do-seu-fork>
   cd ufla-devops-shop
   chmod +x scripts/deploy.sh
   sudo ./scripts/deploy.sh
   ```
4. Ajuste a senha no arquivo `/etc/ufla-shop.env` se necessário e reinicie o serviço:
   ```bash
   sudo systemctl restart ufla-shop
   ```

## 2. Prova de Restart (Resiliência)

Comando: `sudo kill -9 $(pidof uvicorn)`
Saída de `systemctl status ufla-shop` cinco segundos depois:

```text
● ufla-shop.service - UFLA DevOps Shop API
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-09-24 17:41:11 -03; 1min 41s ago
   Main PID: 4949 (uvicorn)
      Tasks: 2 (limit: 9232)
     Memory: 45.2M ()
     CGroup: /system.slice/ufla-shop.service
             └─4949 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --port 8000 --host 127.0.0.1

Sep 24 17:41:11 WNB039021BHZ systemd[1]: Started ufla-shop.service - UFLA DevOps Shop API.
Sep 24 17:41:11 WNB039021BHZ uvicorn[4949]: INFO:     Started server process [4949]
Sep 24 17:41:11 WNB039021BHZ uvicorn[4949]: INFO:     Waiting for application startup.
Sep 24 17:41:11 WNB039021BHZ uvicorn[4949]: 2026-09-24 17:41:11,884 INFO loja: ufla-devops-shop 1.0.0 subindo
Sep 24 17:41:11 WNB039021BHZ uvicorn[4949]: 2026-09-24 17:41:11,928 INFO loja.banco: banco pronto (modo postgres)
Sep 24 17:41:11 WNB039021BHZ uvicorn[4949]: INFO:     Application startup complete.
Sep 24 17:41:11 WNB039021BHZ uvicorn[4949]: INFO:     Uvicorn running on http://127.0.0.1:8000
Sep 24 17:41:12 WNB039021BHZ uvicorn[4949]: INFO:     127.0.0.1:38528 - "GET /ready HTTP/1.1" 200 OK
```

## 3. Testes de Conectividade Nginx

**Requisição HTTPS:**
Comando: `curl -kI https://localhost/ready`
Saída:
```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 24 Sep 2026 20:41:27 GMT
Content-Type: application/json
Content-Length: 31
Connection: keep-alive
```

**Requisição HTTP (Redirecionamento):**
Comando: `curl -I http://localhost`
Saída:
```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 24 Sep 2026 20:41:22 GMT
Content-Type: text/html
Content-Length: 615
```

## 4. Rotação de Backups

Saída de `ls -la /var/backups/ufla-shop` após rodar o script de backup três vezes:

```text
total 12
drwxr-xr-x 2 root root 4096 Sep 24 17:43 .
drwxr-xr-x 3 root root 4096 Sep 24 17:43 ..
-rw-r--r-- 1 root root 1624 Sep 24 17:43 loja-2026-09-24-1743.sql.gz
```

## 5. Prova de Idempotência

As últimas linhas das duas execuções seguidas do `deploy.sh`:

**Primeira execução:**
```text
Executando healthcheck...
Aguardando aplicação... (1/10)
...
--- Deploy concluído com sucesso! ---
```

**Segunda execução:**
```text
--- Iniciando deploy da UFLA DevOps Shop ---
Usuário ufla-shop já existe.
Arquivo de ambiente /etc/ufla-shop.env já existe.
Sincronizando código para /opt/ufla-shop...
...
--- Deploy concluído com sucesso! ---
```
