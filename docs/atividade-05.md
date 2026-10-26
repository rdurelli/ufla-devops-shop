# Atividade 5 — A stack completa

## Imagem no GHCR

A imagem usada pelo serviço `api` é versionada, sem `latest`:

```text
ghcr.io/guilhermesemog/ufla-shop:1.0.0
```

Ela foi construída localmente com essa tag. A publicação exige autenticação no
GHCR com um token que tenha `write:packages`; nenhum token foi colocado no
repositório ou em arquivo.

## `docker compose ps`

```text
NAME                       IMAGE                                    SERVICE   STATUS              PORTS
ufla-devops-shop-api-1     ghcr.io/guilhermesemog/ufla-shop:1.0.0   api       Up (healthy)        8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                       banco     Up (healthy)        5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                           cache     Up (healthy)        6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                        nginx     Up (healthy)        0.0.0.0:80->80/tcp
```

Somente o Nginx publica uma porta. A API, o PostgreSQL e o Redis comunicam-se
pela rede interna do Compose usando os nomes `api`, `banco` e `cache`.

## Roteiro de persistência

Entrada da stack pelo Nginx:

```text
$ curl -I http://localhost
HTTP/1.1 200 OK
Server: nginx/1.27.5
```

Modo completo confirmado pela API:

```text
$ curl -s http://localhost/api/info
{"aplicacao":"ufla-devops-shop","versao":"1.0.0","banco":"postgresql","cache":"redis","instancia":"01159672b5f1"}
```

Produto criado antes do ciclo de reinício:

```text
$ curl -s -X POST http://localhost/api/produtos -H 'Content-Type: application/json' -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}'
{"id":13,"nome":"Prova de persistencia","descricao":"","preco":9.9,"estoque":1}
```

Depois de `docker compose down` e `docker compose up -d --wait`, a busca
encontrou o mesmo produto:

```text
$ curl -s 'http://localhost/api/busca?q=persistencia'
{"termo":"persistencia","total":1,"resultados":[{"id":13,"nome":"Prova de persistencia","preco":9.9,"estoque":1}]}
```

O volume nomeado `dados-postgres` preserva os dados; o `down` foi executado sem
`-v`.

## Configuração e healthchecks

`.env.example` contém somente `POSTGRES_PASSWORD` de exemplo. O arquivo `.env`
local é ignorado pelo Git. O Compose monta `DATABASE_URL` usando essa senha e
usa `${POSTGRES_PASSWORD:?defina no .env}`, recusando a subida quando a senha
não estiver definida.

PostgreSQL usa `pg_isready`, Redis usa `redis-cli ping`, a API consulta
`/health` e o Nginx consulta seu proxy local. `depends_on` sozinho apenas inicia
os containers em uma ordem; ele não garante que um serviço já esteja pronto
para aceitar conexões. `condition: service_healthy` espera os healthchecks do
banco e do cache, e o Nginx espera a API saudável antes de iniciar.