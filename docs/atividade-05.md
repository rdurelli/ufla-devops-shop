# Atividade 5 — A stack completa

## Serviços

```text
$ docker compose ps
NAME                       IMAGE                                    SERVICE   STATUS                    PORTS
ufla-devops-shop-api-1     ghcr.io/paulohsilveir/ufla-shop:1.0.0   api       Up (healthy)              8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                       banco     Up (healthy)              5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                           cache     Up (healthy)              6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                        nginx     Up (healthy)              0.0.0.0:80->80/tcp
```

## Persistência

```text
$ curl -s -X POST http://localhost/api/produtos -H 'Content-Type: application/json' -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}'
{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-19T23:20:40.550748+00:00"}

$ docker compose down
Container ufla-devops-shop-nginx-1 Removed
Container ufla-devops-shop-api-1 Removed
Container ufla-devops-shop-banco-1 Removed
Container ufla-devops-shop-cache-1 Removed
Network ufla-devops-shop_default Removed

$ docker compose up -d --wait
Container ufla-devops-shop-banco-1 Healthy
Container ufla-devops-shop-cache-1 Healthy
Container ufla-devops-shop-api-1 Healthy
Container ufla-devops-shop-nginx-1 Healthy

$ curl -s 'http://localhost/api/busca?q=persistencia'
{"termo":"persistencia","total":1,"resultados":[{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-19T23:20:40.550748+00:00"}]}
```

## Endereço da imagem no GHCR

`ghcr.io/paulohsilveir/ufla-shop:1.0.0`

## `depends_on` e `service_healthy`

O `depends_on` sozinho apenas ordena o início dos containers, mas não garante que banco e cache já estejam prontos para receber conexões. A condição `service_healthy` faz a API esperar os healthchecks dessas dependências passarem antes de iniciar.
