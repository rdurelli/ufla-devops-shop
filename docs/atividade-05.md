# Atividade 5 — A stack completa

A `ufla-devops-shop` no modo completo: API, PostgreSQL, Redis e Nginx, cada um no seu container,
subindo juntos com `docker compose up -d --wait` e mantendo os dados depois de um `down` + `up`.

| Serviço | Imagem | Papel |
|---|---|---|
| `banco` | `postgres:16-alpine` | Produtos e pedidos; dados no volume nomeado `dados-banco`; healthcheck com `pg_isready` |
| `cache` | `redis:7-alpine` | Cache da lista de produtos e carrinhos; healthcheck com `redis-cli ping` |
| `api` | `ghcr.io/c-souzs/ufla-shop:1.0.0` | A aplicação; espera `banco` e `cache` ficarem `healthy`; nenhuma porta publicada |
| `nginx` | `nginx:1.27-alpine` | Proxy reverso (`proxy_pass http://api:8000`); a única porta publicada da stack (`80:80`) |

- **Segredo em um lugar só:** a senha existe apenas no `.env` (fora do git). O `compose.yaml` monta
  a `DATABASE_URL` com `${POSTGRES_PASSWORD:?defina no .env}`, então o compose se recusa a subir
  sem ela. O `.env.example` versionado traz só valores de exemplo.
- **Nomes de serviço como endereço:** dentro da rede do compose, a API acessa
  `postgresql://postgres:...@banco:5432/loja` e `redis://cache:6379/0`; o Nginx acessa `api:8000`.
  `localhost` dentro de um container é o próprio container.
- **`restart: unless-stopped`** nos quatro serviços.
- **Healthcheck do Nginx:** consulta `/nginx-health`, respondido pelo próprio Nginx, para que a
  saúde do proxy não dependa da API (a API tem o seu, herdado do `HEALTHCHECK` da imagem).
- **`curl -I` (HEAD):** o FastAPI responde `405` a `HEAD /`, porque a rota só aceita `GET`. O
  `default.conf` repassa `HEAD` para a API como `GET` (`map` + `proxy_method`) e o Nginx devolve só
  os cabeçalhos ao cliente — por isso o `curl -I http://localhost` dá `200`.

## 1. `docker compose ps` com tudo healthy

```
$ docker compose up -d --wait
 ...
 Container ufla-devops-shop-banco-1  Healthy
 Container ufla-devops-shop-cache-1  Healthy
 Container ufla-devops-shop-api-1  Healthy
 Container ufla-devops-shop-nginx-1  Healthy

$ docker compose ps
NAME                       IMAGE                             COMMAND                  SERVICE   CREATED          STATUS                    PORTS
ufla-devops-shop-api-1     ghcr.io/c-souzs/ufla-shop:1.0.0   "uvicorn app:api --h…"   api       17 seconds ago   Up 11 seconds (healthy)   8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                "docker-entrypoint.s…"   banco     17 seconds ago   Up 16 seconds (healthy)   5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                    "docker-entrypoint.s…"   cache     17 seconds ago   Up 16 seconds (healthy)   6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                 "/docker-entrypoint.…"   nginx     17 seconds ago   Up 5 seconds (healthy)    0.0.0.0:80->80/tcp, [::]:80->80/tcp
```

A ordem do `--wait` mostra o `service_healthy` funcionando: a API só é iniciada depois de `banco` e
`cache` ficarem `Healthy`, e o Nginx só depois da API. Na coluna `PORTS`, só o Nginx tem
mapeamento para o host (`0.0.0.0:80->80`); `api`, `banco` e `cache` mostram apenas a porta
interna.

## 2. Roteiro de persistência

```
$ curl -I http://localhost
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Mon, 12 Oct 2026 02:43:13 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 1262
Connection: keep-alive
accept-ranges: bytes
last-modified: Mon, 12 Oct 2026 01:06:35 GMT
etag: "a9ff234ae97d26332d3f63203cb8d9cd"

$ curl -s http://localhost/api/info
{"aplicacao":"ufla-devops-shop","versao":"1.0.0","banco":"postgresql","cache":"redis","instancia":"4a87ee505f65"}

$ curl -s -X POST http://localhost/api/produtos -H 'Content-Type: application/json' \
       -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}'
{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-12T02:43:13.559617+00:00"}

$ docker compose down
 Container ufla-devops-shop-nginx-1  Stopping
 Container ufla-devops-shop-nginx-1  Stopped
 Container ufla-devops-shop-nginx-1  Removing
 Container ufla-devops-shop-nginx-1  Removed
 Container ufla-devops-shop-api-1  Stopping
 Container ufla-devops-shop-api-1  Stopped
 Container ufla-devops-shop-api-1  Removing
 Container ufla-devops-shop-api-1  Removed
 Container ufla-devops-shop-cache-1  Stopping
 Container ufla-devops-shop-banco-1  Stopping
 Container ufla-devops-shop-banco-1  Stopped
 Container ufla-devops-shop-banco-1  Removing
 Container ufla-devops-shop-banco-1  Removed
 Container ufla-devops-shop-cache-1  Stopped
 Container ufla-devops-shop-cache-1  Removing
 Container ufla-devops-shop-cache-1  Removed
 Network ufla-devops-shop_default  Removing
 Network ufla-devops-shop_default  Removed

$ docker compose up -d --wait
 ...
 Container ufla-devops-shop-banco-1  Healthy
 Container ufla-devops-shop-cache-1  Healthy
 Container ufla-devops-shop-api-1  Healthy
 Container ufla-devops-shop-nginx-1  Healthy

$ curl -s 'http://localhost/api/busca?q=persistencia'
{"termo":"persistencia","total":1,"resultados":[{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1,"criado_em":"2026-10-12T02:43:13.559617+00:00"}]}

$ docker volume ls
DRIVER    VOLUME NAME
local     8c25853ca3554151488ce9d9bd2c154d18275925d926d35d2d4f38d7f7155170
local     65f7f418a724c8db040270f49aff3882ffd2c35f5da5a22e0ea7537165b8dd0a
local     d5f4e30296225d40436c3a329f6a79482d0f14c405fd7cb142ff3352c50449a9
local     ufla-devops-shop_dados-banco
```

O produto criado antes do `down` (id 13, mesmo `criado_em`) continua lá depois do `up`: o `down`
(sem `-v`) remove os containers e a rede, mas não o volume nomeado `ufla-devops-shop_dados-banco`,
onde o PostgreSQL guarda os dados. Os volumes com nome em hash são anônimos — a imagem do Redis
declara `VOLUME /data`, e cada container novo ganha um; o cache não precisa sobreviver.

## 3. Imagem no GHCR

**`ghcr.io/c-souzs/ufla-shop:1.0.0`** — pacote público, em
<https://github.com/users/c-souzs/packages/container/package/ufla-shop>.

```bash
docker pull ghcr.io/c-souzs/ufla-shop:1.0.0   # funciona sem docker login
```

A tag é SemVer, não `latest`: quem lê o `compose.yaml` sabe exatamente qual versão está rodando, e
um rollback é só voltar para a tag anterior.

## 4. Por que `depends_on` sozinho não resolve a ordem de subida?

`depends_on` sozinho só garante que o container do banco foi **iniciado** antes do da API, mas
iniciar o container não significa que o PostgreSQL já aceita conexões — ele ainda leva alguns
segundos inicializando, e a API que conecta nesse intervalo recebe `connection refused`. Com
`condition: service_healthy`, o compose espera o healthcheck do banco (`pg_isready`) e do cache
(`redis-cli ping`) passar antes de iniciar a API, ou seja, a ordem passa a ser "pronto", não só
"ligado".
