# Atividade-05 - Patricia Souza Couto

## (a) docker compose ps
```bash
docker compose ps
```
NAME                       IMAGE                              COMMAND                  SERVICE   CREATED         STATUS                   PORTS
ufla-devops-shop-api-1     ghcr.io/bikindev/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       2 minutes ago   Up 2 minutes (healthy)   8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                 "docker-entrypoint.s…"   banco     2 minutes ago   Up 2 minutes (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                     "docker-entrypoint.s…"   cache     2 minutes ago   Up 2 minutes (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                  "/docker-entrypoint.…"   nginx     2 minutes ago   Up 2 minutes             0.0.0.0:80->80/tcp, [::]:80->80/tcp

### a.1 Conferir se a aplicação conectou no PostgreSQL e no Redis
```bash
curl -s http://localhost/api/info
```
{"aplicacao":"ufla-devops-shop","versao":"1.0.0","banco":"postgresql","cache":"redis","instancia":"d652521e66c6"}

## (b) Roteiro de persistencia (Parte 2)
### b.1 POST: Cadastrar um produto no banco
```bash
curl -s -X POST http://localhost/api/produtos -H 'Content-Type: application/json' -d '{"nome": "Prova de persistencia", "preco": 9.9, "estoque": 1}'
```
{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-12

### b.2 DOWN e UP: Derrubar a stack inteira e subir novamente
```bash
docker compose down
docker compose up -d --wait
```
 ✔ Image postgres:16-alpine           Pulled                                      15.2s
 ✔ Image redis:7-alpine               Pulled                                      15.0s
 ✔ Image nginx:1.27-alpine            Pulled                                      14.8s
 ✔ Network ufla-devops-shop_default   Created                                      0.1s
 ✔ Volume ufla-devops-shop_dados-pg   Created                                      0.0s
 ✔ Container ufla-devops-shop-cache-1 Healthy                                      8.8s
 ✔ Container ufla-devops-shop-banco-1 Healthy                                      8.8s
 ✔ Container ufla-devops-shop-api-1   Healthy                                     12.2s
 ✔ Container ufla-devops-shop-nginx-1 Healthy                                      7.0s

### b.3 Buscar o produto cadastrado e persistido
```bash
curl -s 'http://localhost/api/busca?q=persistencia'
```
{"termo":"persistencia","total":1,"resultados":[{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":0,"criado_em":"2026-10-12T00:14:16.555105+00:00"}]}

## (c) Endereco publico da imagem no GHCR:
ghcr.io/bikindev/ufla-shop:1.0.0

## (d) por que `depends on` sozinho não resolve a ordem de subida e o `service_healthy` acrescenta?
O depends_on sozinho apenas garante que o container inicie apos outro container, mas nao necessariamente espera a aplicacao interna terminar de inicializar. Como o PostgreSQL e o Redis podem levar alguns segundos para abrir as conexoes, a API tentaria conectar antes da hora e falharia com erro de conexao. O service_healthy faz a API esperar ate que o banco e o cache passem no healthcheck e estejam prontos para aceitar requisicoes.
