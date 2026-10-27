# Atividade 5 — A stack completa

**Disciplina:** DevOps na Prática — DCC/UFLA (Turmas 10A-14A)
**Aluno:** Estevão Augusto
**Branch:** `atividade-05`

---

## (a) Saída de `docker compose ps` com tudo *healthy*

Comando executado:

```bash
docker compose ps
```

Saída:

```text
NAME                       IMAGE                                    COMMAND                  SERVICE   CREATED   STATUS                   PORTS
ufla-devops-shop-api-1     ghcr.io/estevaoaugusto/ufla-shop:1.0.0   "uvicorn app.princip…"   api       7 minutes ago   Up 7 minutes (healthy)   8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                       "docker-entrypoint.s…"   banco     7 minutes ago   Up 7 minutes (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                           "docker-entrypoint.s…"   cache     7 minutes ago   Up 7 minutes (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                        "/docker-entrypoint.…"   nginx     7 minutes ago   Up 7 minutes             0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

---

## (b) Roteiro de persistência

### 1. Subida da stack

```bash
cp .env.example .env
docker compose up -d --wait
```

```text
estevao:~/Downloads/Devops na Pratica/Atividades/ufla-devops-shop ➜ cp .env.example .env
estevao:~/Downloads/Devops na Pratica/Atividades/ufla-devops-shop ➜ docker compose up -d --wait
[+] up 51/51
 ✔ Image redis:7-alpine                         Pulled                                                         16.1s
 ✔ Image ghcr.io/estevaoaugusto/ufla-shop:1.0.0 Pulled                                                         23.4s
 ✔ Image postgres:16-alpine                     Pulled                                                         63.5s
 ✔ Image nginx:1.27-alpine                      Pulled                                                         21.3s
 ✔ Network ufla-devops-shop_default             Created                                                         0.2s
 ✔ Container ufla-devops-shop-banco-1           Healthy                                                        24.5s
 ✔ Container ufla-devops-shop-cache-1           Healthy                                                        24.5s
 ✔ Container ufla-devops-shop-api-1             Healthy                                                        23.5s
 ✔ Container ufla-devops-shop-nginx-1           Healthy   
```

### 2. Acesso via Nginx

```bash
curl -I http://localhost
```

```text
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Tue, 27 Oct 2026 12:36:10 GMT
Content-Type: application/octet-stream
Content-Length: 0
Connection: keep-alive
```

```bash
curl -s http://localhost/api/info
```

```text
{"aplicacao":"ufla-devops-shop","versao":"1.0.0","banco":"postgresql","cache":"redis","instancia":"b0b506722ff5"}
```

### 3. POST do produto

```bash
curl -s -X POST http://localhost/api/produtos \
  -H 'Content-Type: application/json' \
  -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}'
```

```text
{"id":15,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-27T12:37:34.147375+00:00"}
```

### 4. `docker compose down` (sem `-v`)

```bash
docker compose down
```

```text
[+] down 5/5
 ✔ Container ufla-devops-shop-nginx-1 Removed                                                                   0.5s
 ✔ Container ufla-devops-shop-api-1   Removed                                                                   1.3s
 ✔ Container ufla-devops-shop-cache-1 Removed                                                                   0.7s
 ✔ Container ufla-devops-shop-banco-1 Removed                                                                   0.8s
 ✔ Network ufla-devops-shop_default   Removed                                                                   0.2s
```

### 5. `docker compose up` novamente

```bash
docker compose up -d --wait
```

```text
[+] up 5/5
 ✔ Network ufla-devops-shop_default   Created                                                                   0.1s
 ✔ Container ufla-devops-shop-banco-1 Healthy                                                                  23.5s
 ✔ Container ufla-devops-shop-cache-1 Healthy                                                                  23.5s
 ✔ Container ufla-devops-shop-api-1   Healthy                                                                  23.1s
 ✔ Container ufla-devops-shop-nginx-1 Healthy                                                                  22.7s
```

### 6. Busca encontrando o produto

```bash
curl -s 'http://localhost/api/busca?q=persistencia'
```

```text
{"termo":"persistencia","total":3,"resultados":[{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-27T04:22:27.503041+00:00"},{"id":14,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-27T04:22:33.827539+00:00"},{"id":15,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-27T12:37:34.147375+00:00"}]}
```

### 7. Apenas o Nginx com porta publicada

```bash
docker compose ps
```

```text
NAME                       IMAGE                                    COMMAND                  SERVICE   CREATED        STATUS                        PORTS
ufla-devops-shop-api-1     ghcr.io/estevaoaugusto/ufla-shop:1.0.0   "uvicorn app.princip…"   api       About a minute ago   Up About a minute (healthy)   8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                       "docker-entrypoint.s…"   banco     About a minute ago   Up About a minute (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                           "docker-entrypoint.s…"   cache     About a minute ago   Up About a minute (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                        "/docker-entrypoint.…"   nginx     About a minute ago   Up About a minute             0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

---

## (c) Endereço público da imagem no GHCR

```text
ghcr.io/estevaoaugusto/ufla-shop:1.0.0
```

- **Página do pacote:** https://github.com/users/EstevaoAugusto/packages/container/package/ufla-shop
- **Visibilidade:** Public
- **Tag:** `1.0.0` (SemVer)

---

## (d) Por que `depends_on` sozinho não resolve a ordem de subida, e o que o `service_healthy` acrescenta?

O `depends_on` sozinho só controla a ordem em que os containers são criados e iniciados: o Compose sobe o banco antes da API, mas não espera o PostgreSQL terminar de inicializar e aceitar conexões. Por isso a API pode subir cedo demais e falhar com `connection refused`, já que o container do banco estar "rodando" não significa que o serviço dentro dele está pronto. O `condition: service_healthy` acrescenta essa espera: o Compose só inicia a API depois que o healthcheck do banco (`pg_isready`) e o do cache (`redis-cli ping`) passam, garantindo que as dependências estejam prontas para receber tráfego.
