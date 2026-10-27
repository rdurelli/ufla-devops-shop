# Atividade 05 — A stack completa

## 1. Serviços

```text
$ docker compose ps
NAME                       IMAGE                             COMMAND                  SERVICE   CREATED          STATUS                    PORTS
ufla-devops-shop-api-1     ghcr.io/gnine11/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       31 seconds ago   Up 24 seconds (healthy)   8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                "docker-entrypoint.s…"   banco     31 seconds ago   Up 30 seconds (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                    "docker-entrypoint.s…"   cache     31 seconds ago   Up 30 seconds (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                 "/docker-entrypoint.…"   nginx     31 seconds ago   Up 19 seconds (healthy)   0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

## 2. Persistência dos dados

Saídas resumidas do teste:

```text
$ curl -fsS -X POST http://localhost/api/produtos -H 'Content-Type: application/json' -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}'
{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-27T22:04:59.033551+00:00"}

$ docker compose down
 Container ufla-devops-shop-nginx-1  Removed
 Container ufla-devops-shop-api-1  Removed
 Container ufla-devops-shop-banco-1  Removed
 Container ufla-devops-shop-cache-1  Removed
 Network ufla-devops-shop_default  Removed

$ docker compose up -d --wait --wait-timeout 120
 Container ufla-devops-shop-cache-1  Healthy
 Container ufla-devops-shop-api-1  Healthy
 Container ufla-devops-shop-banco-1  Healthy
 Container ufla-devops-shop-nginx-1  Healthy

$ curl -fsS 'http://localhost/api/busca?q=persistencia'
{"termo":"persistencia","total":1,"resultados":[{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-27T22:04:59.033551+00:00"}]}
```

Depois do `down` e do `up`, o produto continuou no banco.

## 3. Imagem no GHCR

`ghcr.io/gnine11/ufla-shop:1.0.0`

A [imagem](https://github.com/users/GNINE11/packages/container/package/ufla-shop) está pública e o download sem login foi testado.

## 4. Por que depends_on sozinho não resolve a ordem de subida?

O `depends_on` só define a ordem de início dos containers, mas o banco e o cache podem ainda não estar prontos. Com `service_healthy`, a API espera os healthchecks dos dois passarem antes de iniciar.
