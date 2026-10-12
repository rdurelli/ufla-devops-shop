# Atividade 4 — Containerizar a aplicação

A `ufla-devops-shop` empacotada numa imagem Docker: build multi-stage, base Alpine, usuário
não-root, `CMD` na forma exec e `HEALTHCHECK` em `/health`. Sem variável de ambiente, o container
roda em modo autônomo (SQLite em `/dados/loja.db` + cache em memória).

| Arquivo | Função |
|---|---|
| `Dockerfile` | Estágio `build` instala as dependências num venv; o estágio final recebe só o venv, `app/` e `static/` |
| `.dockerignore` | Deixa fora do contexto `.git`, `.venv`, `__pycache__`, `tests`, `*.db`, `.env`, chaves, dados e docs |

## 1. Antes e depois

A primeira versão que funcionou (`ufla-shop:v1`) era o Dockerfile mais direto possível: um estágio
só, `python:3.12-slim`, `COPY . .` e `pip install -r requirements.txt`.

```
$ docker images ufla-shop
IMAGE           ID             DISK USAGE   CONTENT SIZE   EXTRA
ufla-shop:1.0   a8f4aaaaf092        126MB         29.4MB
ufla-shop:v1    cb44a49b9e45        275MB         71.3MB
```

| Imagem | Descompactada (soma das camadas) | Compactada (`CONTENT SIZE`) |
|---|---|---|
| `ufla-shop:v1` — primeira versão | **203 MB** | 71,3 MB |
| `ufla-shop:1.0` — final | **96 MB** | 29,4 MB |

> **Sobre os números:** o Docker 29 usa o *containerd image store*. Nele, `DISK USAGE` soma a
> imagem compactada (o que é baixado do registry) e a descompactada (o que vai para o disco).
> Por isso aparecem 126 MB e 275 MB. O tamanho que se compara com a meta de 150 MB é o
> descompactado, ou seja, a soma das camadas do `docker history`: **96 MB**. Nesse mesmo store,
> o `docker image inspect --format '{{.Size}}'` mostra o tamanho compactado (30M). As duas medidas
> ficam abaixo de 150 MB.

## 2. O que mudou e quanto cada mudança economizou

Para medir cada corte isoladamente, construí as versões intermediárias e somei as camadas de cada
uma (`docker history --human=false`):

| # | Mudança | Tamanho | Diferença |
|---|---|---|---|
| 0 | v1: slim, um estágio, `pip install` | 203,2 MB | — |
| 1 | `pip install --no-cache-dir` | 189,9 MB | **−13,3 MB** (cache do pip em `/root/.cache/pip`) |
| 2 | Multi-stage com venv, ainda em slim | 193,6 MB | +3,7 MB (o venv traz uma segunda cópia do pip) |
| 3 | Remover o pip e os `__pycache__` do venv no estágio de build | 169,7 MB | **−23,9 MB** |
| 4 | Base do estágio final `python:3.12-alpine` | **96,2 MB** | **−73,5 MB** |

O que explica cada corte:

- **Cache do pip (−13 MB):** sem `--no-cache-dir`, o pip guarda os *wheels* baixados dentro da
  camada. Esse cache só serve para reinstalar, o que não acontece num container.
- **Multi-stage:** sozinho não economiza nada; o venv copiado traz até um pip a mais. A vantagem é
  que o estágio `build` vira descartável: o que for apagado lá (pip, `__pycache__`) não deixa
  camada com o arquivo original na imagem final. Apagar com `RUN rm` no próprio estágio final não
  reduz nada, porque o arquivo continua na camada de baixo.
- **pip e `__pycache__` (−24 MB):** em execução ninguém instala pacote, então o pip do venv sai
  (≈12 MB). Os `.pyc` (≈15 MB) são só um atalho para iniciar mais rápido; com
  `PYTHONDONTWRITEBYTECODE=1` o Python compila em memória e não tenta gravar no disco, que pertence
  ao root.
- **Alpine (−73,5 MB):** é o corte que realmente bate a meta. A base slim tem 134 MB de camadas
  (Debian + Python), e a Alpine tem 62 MB (musl + Python). Todas as dependências têm *wheels* para
  musl, então nada precisa ser compilado. As dependências ficaram com o mesmo tamanho nas duas
  bases: 33,7 MB no venv final, quase metade só o `psycopg[binary]` (`libpq` + OpenSSL embutidos).
- **`COPY` explícito + `.dockerignore`:** o final copia só `app/` e `static/` (≈78 kB); o
  `.dockerignore` garante que `.git`, `.env`, `.venv`, `tests` e os 87 MB de `dados/` nem entrem
  no contexto do build.

Camadas da imagem final:

```
$ docker history --format "{{.Size}}\t{{.CreatedBy}}" ufla-shop:1.0
0B      CMD ["uvicorn" "app:api" "--host" "0.0.0.0" "--port" "8000"]
0B      HEALTHCHECK &{["CMD" "python" "-c" "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"] ...
0B      EXPOSE [8000/tcp]
0B      USER loja
24.6kB  COPY static/ static/ # buildkit
53.2kB  COPY app/ app/ # buildkit
33.7MB  COPY /opt/venv /opt/venv # buildkit
8.19kB  WORKDIR /app
36.9kB  RUN /bin/sh -c addgroup -S -g 10001 loja && adduser ... && install -d -o loja -g loja /dados
0B      ENV PATH=/opt/venv/bin:... PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 SQLITE_PATH=/dados/loja.db
0B      CMD ["python3"]
16.4kB  RUN /bin/sh -c set -eux; for src in idle3 pip3 pydoc3 python3 python3-config; ...
50.4MB  RUN /bin/sh -c set -eux; apk add --no-cache --virtual .build-deps ...
2.83MB  RUN /bin/sh -c set -eux; apk add --no-cache ca-certificates tzdata
9.08MB  ADD alpine-minirootfs-3.24.2-x86_64.tar.gz /
```

Camadas da v1, para comparação:

```
$ docker history ufla-shop:v1
IMAGE          CREATED          CREATED BY                                      SIZE
cb44a49b9e45   2 seconds ago    CMD ["uvicorn" "app:api" "--host" "0.0.0.0" …   0B
<missing>      2 seconds ago    HEALTHCHECK &{["CMD" "python" "-c" "import u…   0B
<missing>      2 seconds ago    USER loja                                       0B
<missing>      2 seconds ago    RUN /bin/sh -c useradd --system loja && chow…   115kB
<missing>      2 seconds ago    RUN /bin/sh -c pip install -r requirements.t…   69MB
<missing>      11 seconds ago   COPY . . # buildkit                             77.8kB
<missing>      11 seconds ago   WORKDIR /app                                    8.19kB
<missing>      6 days ago       CMD ["python3"]                                 0B
<missing>      6 days ago       RUN /bin/sh -c set -eux;  for src in idle3 p…   16.4kB
<missing>      6 days ago       RUN /bin/sh -c set -eux;   savedAptMark="$(a…   41.4MB
<missing>      6 days ago       RUN /bin/sh -c set -eux;  apt-get update;  a…   4.94MB
<missing>      7 days ago       # debian.sh --arch 'amd64' out/ 'trixie' '@1…   87.7MB
```

## 3. Verificação

```
$ docker build -t ufla-shop:1.0 .
[+] Building 11.5s (14/14) FINISHED

$ docker image inspect --format '{{.Size}}' ufla-shop:1.0 | numfmt --to=si
30M

$ docker run -d --name loja -p 8000:8000 ufla-shop:1.0
a6dd6b846da2f8627a079a58ef6a280634d1b8dc085ff873398660962d1d7221

$ docker run --rm ufla-shop:1.0 id -u
10001

$ docker run --rm ufla-shop:1.0 ls -a
.
..
app
static

$ sleep 10 && docker inspect --format '{{.State.Health.Status}}' loja
healthy

$ curl -s localhost:8000/health
{"status":"ok","versao":"1.0.0"}

$ curl -s localhost:8000/api/produtos | python3 -c 'import json,sys; print(len(json.load(sys.stdin)), "produtos")'
12 produtos

$ time docker stop loja
loja

real	0m0,311s
user	0m0,006s
sys	0m0,006s
```

- **Não-root:** o processo roda como `loja` (UID 10001). O SQLite é gravado em `/dados`, a única
  pasta que pertence a esse usuário; `/app` e `/opt/venv` continuam do root, então a aplicação não
  consegue alterar o próprio código.
- **`docker stop` em 0,3 s:** com o `CMD` na forma exec, o uvicorn é o PID 1 e recebe o SIGTERM
  direto, encerrando na hora. Na forma shell, o PID 1 seria o `sh`, que não repassa o sinal, e o
  Docker esperaria os 10 s antes do SIGKILL.
- **`HEALTHCHECK`:** usa o `urllib` do próprio Python, porque a Alpine não tem `curl`, e consulta
  `127.0.0.1:8000`, que é o endereço de dentro do container. Com `--interval=5s` e
  `--start-period=5s`, o container já está `healthy` antes dos 10 s da verificação.

## 4. Por que o `HEALTHCHECK` consulta `/health` e não `/ready`?

O `HEALTHCHECK` responde se **este processo** está vivo, e o `/health` só confirma isso, sem tocar
em banco nem cache; o `/ready` depende do PostgreSQL e do Redis, e se um deles caísse o container
seria marcado `unhealthy` (e reiniciado por um orquestrador) mesmo com a aplicação perfeita.
Reiniciar a API não conserta o banco, só derruba todas as réplicas juntas — por isso o `/ready`
serve para decidir se o container recebe tráfego (readiness), e o `/health` para decidir se ele
precisa ser reiniciado (liveness).
