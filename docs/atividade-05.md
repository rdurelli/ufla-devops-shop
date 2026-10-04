# Atividade 5 -- stack com compose e GHCR

Autor: Felipe Geraldo de Oliveira (@FelipeOliveira456)

Quatro servicos: `banco` (postgres:16-alpine + volume `loja-dados`), `cache` (redis:7-alpine), `api` (`ghcr.io/felipeoliveira456/ufla-shop:1.0.0`) e `nginx` (unica porta publicada, 80). Senha so no `.env`. `DATABASE_URL` montada com `${POSTGRES_PASSWORD:?defina no .env}`. Healthcheck no banco e no cache; a API espera `service_healthy`. `restart: unless-stopped` nos quatro.

Por que `depends_on` sozinho nao resolve: ele so espera o container do postgres existir, nao que o banco aceite conexao. Na primeira subida a API tomava connection refused. `condition: service_healthy` espera o `pg_isready` / `redis-cli ping` -- a API so sobe quando da para usar.

Imagem: https://github.com/FelipeOliveira456/ufla-shop/pkgs/container/ufla-shop (tag `1.0.0`). Se o link da pagina do pacote for outro, cole o que aparecer depois do push.

<!-- EVIDENCIAS -->

## (a) docker compose ps

```
NAME                       IMAGE                                       COMMAND                  SERVICE   CREATED          STATUS                    PORTS
ufla-devops-shop-api-1     ghcr.io/felipeoliveira456/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       13 seconds ago   Up 7 seconds (healthy)    8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                          "docker-entrypoint.s…"   banco     14 seconds ago   Up 13 seconds (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                              "docker-entrypoint.s…"   cache     14 seconds ago   Up 13 seconds (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                           "/docker-entrypoint.…"   nginx     13 seconds ago   Up 7 seconds              0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

## (b) Persistencia: POST, down, up, busca

```
curl -I:
HTTP/1.1 405 Method Not Allowed
Server: nginx/1.27.5
Date: Sun, 04 Oct 2026 23:00:12 GMT
Content-Type: application/json
Content-Length: 31
Connection: keep-alive
allow: GET


/api/info:
{"aplicacao":"ufla-devops-shop","versao":"1.0.0","banco":"postgresql","cache":"redis","instancia":"1e3b5ae2ac61"}

POST /api/produtos:
{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-04T23:00:12.790511+00:00"}

depois do down + up, busca persistencia:
{"termo":"persistencia","total":1,"resultados":[{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-04T23:00:12.790511+00:00"}]}

ps final:
NAME                       IMAGE                                       COMMAND                  SERVICE   CREATED          STATUS                    PORTS
ufla-devops-shop-api-1     ghcr.io/felipeoliveira456/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       12 seconds ago   Up 6 seconds (healthy)    8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                          "docker-entrypoint.s…"   banco     12 seconds ago   Up 11 seconds (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                              "docker-entrypoint.s…"   cache     12 seconds ago   Up 11 seconds (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                           "/docker-entrypoint.…"   nginx     12 seconds ago   Up 5 seconds              0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

## (c) Imagem no GHCR

ghcr.io/felipeoliveira456/ufla-shop:1.0.0

