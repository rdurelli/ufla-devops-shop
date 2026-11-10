# Atividade 5 — A stack completa

## Serviços
```
NAME                       IMAGE                                   COMMAND                  SERVICE   CREATED          STATUS                    PORTS
ufla-devops-shop-api-1     ghcr.io/filipesilva07/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       36 seconds ago   Up 29 seconds (healthy)   8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                      "docker-entrypoint.s…"   banco     37 seconds ago   Up 35 seconds (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                          "docker-entrypoint.s…"   cache     37 seconds ago   Up 35 seconds (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                       "/docker-entrypoint.…"   nginx     36 seconds ago   Up 23 seconds             0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

## Teste de persistência
Produto criado antes do reinício:
```json
{"id":13,"nome":"Prova de persistencia","preco":9.9,"estoque":1}
```

Após docker compose down e docker compose up -d --wait:
```json
{"termo":"persistencia","total":1,"resultados":[{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-11-10T21:58:02.217812+00:00"}]}
```

## Imagem pública
ghcr.io/filipesilva07/ufla-shop:1.0.0

## Healthchecks
O depends_on simples controla apenas a ordem de inicialização, sem garantir que os serviços estejam prontos.
Com condition: service_healthy, a API espera PostgreSQL e Redis ficarem saudáveis antes de iniciar.

## Evidências da reinicialização

Comandos executados:

- `docker compose down`
- `docker compose up -d --wait`
- `curl -s 'http://localhost/api/busca?q=persistencia'`

Os quatro serviços voltaram a funcionar e ficaram saudáveis.
A busca retornou `total: 1`, confirmando que o produto de ID 13
continuou no PostgreSQL após a remoção e recriação dos contêineres.

## Resultado do teste HTTP

- GET `/`: HTTP 200
- GET `/api/info`: banco `postgresql` e cache `redis`
- POST `/api/produtos`: produto criado com ID 13
