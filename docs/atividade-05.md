# Atividade 05 — A stack completa

## Estado da stack

```console
$ docker compose ps
NAME                       IMAGE                                      COMMAND                  SERVICE   CREATED          STATUS                    PORTS
ufla-devops-shop-api-1     ghcr.io/thiagoferreira13/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       32 seconds ago   Up 26 seconds (healthy)   8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                         "docker-entrypoint.s…"   banco     32 seconds ago   Up 31 seconds (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                             "docker-entrypoint.s…"   cache     32 seconds ago   Up 31 seconds (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                          "/docker-entrypoint.…"   nginx     32 seconds ago   Up 20 seconds (healthy)   0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

## Teste de persistência

### Criação do produto

```console
$ curl -s -X POST http://localhost/api/produtos \
  -H 'Content-Type: application/json' \
  -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}'
{"id":15,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-09-30T14:10:47.901358+00:00"}
```

### Remoção da stack

```console
$ docker compose down
[+] down 5/5
 ✔ Container ufla-devops-shop-nginx-1 Removed
 ✔ Container ufla-devops-shop-api-1   Removed
 ✔ Container ufla-devops-shop-cache-1 Removed
 ✔ Container ufla-devops-shop-banco-1 Removed
 ✔ Network ufla-devops-shop_default   Removed
```

### Subida da stack

```console
$ docker compose up -d --wait
[+] up 5/5
 ✔ Network ufla-devops-shop_default   Created
 ✔ Container ufla-devops-shop-banco-1 Healthy
 ✔ Container ufla-devops-shop-cache-1 Healthy
 ✔ Container ufla-devops-shop-api-1   Healthy
 ✔ Container ufla-devops-shop-nginx-1 Healthy
```

### Busca após a recriação

```console
$ curl -s 'http://localhost/api/busca?q=persistencia'
{"termo":"persistencia","total":3,"resultados":[{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-09-29T23:10:27.321864+00:00"},{"id":14,"nome":"persistencia-manual-20260929201937","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-09-29T23:19:43.320722+00:00"},{"id":15,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-09-30T14:10:47.901358+00:00"}]}
```

O produto de ID 15 criado antes do `docker compose down` continuou disponível após a recriação da stack, confirmando a persistência dos dados no volume nomeado do PostgreSQL.

## Imagem pública no GHCR

```text
ghcr.io/thiagoferreira13/ufla-shop:1.0.0
```

## `depends_on` e `service_healthy`

`depends_on` sozinho garante apenas a ordem de inicialização dos containers, mas não garante que o serviço dentro deles já esteja pronto para receber conexões, pois um container iniciado não significa necessariamente um serviço pronto. A condição `service_healthy` faz o Compose aguardar o healthcheck do banco e do cache ser aprovado antes de iniciar a API, reduzindo falhas durante a inicialização. Ainda assim, isso resolve apenas a ordem de subida: se uma dependência cair posteriormente, a aplicação também precisa ser resiliente, tratando a perda de conexão e conseguindo se reconectar, pois ordem de inicialização não substitui resiliência.