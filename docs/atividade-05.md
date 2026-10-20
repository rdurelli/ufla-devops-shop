Nome do aluno: João Pedro Dos Reis Moura

# Relatório de Evidências - Atividade 05: A Stack Completa

## (a) Saída do comando `docker compose ps`
```text
NAME                         IMAGE                                   COMMAND                  SERVICE   CREATED         STATUS                   PORTS
ufla-devops-shop-jp-api-1     ghcr.io/jotapemoura/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       5 minutes ago   Up 5 minutes (healthy)   8000/tcp
ufla-devops-shop-jp-banco-1   postgres:16-alpine                     "docker-entrypoint.s…"   banco     5 minutes ago   Up 5 minutes (healthy)   5432/tcp
ufla-devops-shop-jp-cache-1   redis:7-alpine                         "docker-entrypoint.s…"   cache     5 minutes ago   Up 5 minutes (healthy)   6379/tcp
ufla-devops-shop-jp-nginx-1   nginx:1.27-alpine                      "/docker-entrypoint.…"   nginx     5 minutes ago   Up 5 minutes             0.0.0.0:80->80/tcp

1. Inserção do produto via POST
Bash

$ curl -s -X POST http://localhost/api/produtos -H 'Content-Type: application/json' \
  -d '{"nome": "Prova de persistencia", "preco": 9.9, "estoque": 1}'

{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2

docker compose up -d --wait 
[+] up 4/4
 ✔ Container ufla-devops-shop-jp-cache-1 Healthy                                                                                                                     3.8s
 ✔ Container ufla-devops-shop-jp-api-1   Healthy                                                                                                                     3.8s
 ✔ Container ufla-devops-shop-jp-banco-1 Healthy                                                                                                                     3.8s
 ✔ Container ufla-devops-shop-jp-nginx-1 Healthy                                                                                                                     3.1s
$ docker compose ps
NAME                          IMAGE                                 COMMAND                  SERVICE   CREATED         STATUS                   PORTS
ufla-devops-shop-jp-api-1     ghcr.io/jotapemoura/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       9 minutes ago   Up 9 minutes (healthy)   8000/tcp
ufla-devops-shop-jp-banco-1   postgres:16-alpine                    "docker-entrypoint.s…"   banco     9 minutes ago   Up 9 minutes (healthy)   5432/tcp
ufla-devops-shop-jp-cache-1   redis:7-alpine                        "docker-entrypoint.s…"   cache     9 minutes ago   Up 9 minutes (healthy)   6379/tcp
ufla-devops-shop-jp-nginx-1   nginx:1.27-alpine                     "/docker-entrypoint.…"   nginx     9 minutes ago   Up 8 minutes             0.0.0.0:80->80/tcp, [::]:80->80/tcp
$ docker compose logs --tail=20 api
api-1  | INFO:     127.0.0.1:58004 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:58010 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:48506 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:37456 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:37462 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:42264 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:41794 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:41800 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:48530 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:42702 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:42718 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:59768 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:54876 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:54888 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:37100 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:37110 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:39714 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:43778 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:43782 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     127.0.0.1:39884 - "GET /health HTTP/1.1" 200 OK
$ curl -s http://localhost/api/info
{"aplicacao":"ufla-devops-shop","versao":"1.0.0","banco":"postgresql","cache":"redis","instancia":"61f8ca137920"}

curl -s 'http://localhost/api/busca?q=persistencia'
{"termo":"persistencia","total":0,"resultados":[]}


Endereço Público da Imagem no GHCR

https://github.com/jotapemoura/ufla-shop/pkgs/container/ufla-shop


Pergunta: Por que depends_on sozinho não resolve a ordem de subida e o que service_healthy acrescenta?

O depends_on simples apenas garante a ordem de inicialização do processo/container, ou seja, inicia o container da API assim que o processo do banco de dados é criado, mas antes de o PostgreSQL estar pronto para aceitar conexões. A cláusula condition: service_healthy instrui o Docker Compose a aguardar que a verificação de saúde (healthcheck via pg_isready) retorne sucesso antes de iniciar o serviço dependente, evitando falhas de conexão (connection refused) na inicialização da API.
EOF


---



 


