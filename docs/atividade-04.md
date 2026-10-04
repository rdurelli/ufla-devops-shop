# Atividade 4 -- imagem Docker

Autor: Felipe Geraldo de Oliveira (@FelipeOliveira456)

A primeira versao que funcionou foi `python:3.12-slim` num unico estagio, com `pip install` na imagem final. Pelos numeros de `docs/aplicacao.md` (setembro 2026, amd64) isso fica em torno de **168 MB** -- ja passa dos 150 MB. Multi-stage no slim, tirando pip e cache, ainda fica uns **155 MB**.

A versao final troca a base do estagio 2 por `python:3.12-alpine` (~60 MB vazia, ~101 MB com as deps). O builder instala a venv; o estagio final so copia `/opt/venv`, `app/` e `static/`. Nao leva `.git`, `.venv`, testes nem `.env` (`.dockerignore`). Usuario `loja` (uid 1000). `CMD` em forma exec. `SQLITE_PATH=/tmp/loja.db` para o nao-root conseguir escrever. HEALTHCHECK em Python (`urllib`), sem instalar curl.

Por que `/health` e nao `/ready`: `/health` e liveness -- o processo esta vivo, sem tocar em banco nem cache. `/ready` e readiness -- so 200 se as dependencias respondem. No modo desta semana as duas passam, mas a partir da Atividade 5 um redis lento faria o Docker matar o container se o check fosse `/ready`. Healthcheck de imagem e "o processo vive"; "posso receber trafego" fica para a probe de readiness no Kubernetes.

Rode os comandos da Parte 2 e cole as saidas abaixo (ou `./scripts/coletar-evidencias-04.sh` depois de copiar o script para o repo).

<!-- EVIDENCIAS -->

## 1. Tamanho: primeira vs final

```
ufla-shop	1.0	107MB
ufla-shop:1.0 inspect: 107M
```

Primeira que funcionou (slim, um estagio): ~168 MB, segundo docs/aplicacao.md.
Final (alpine multi-stage): 107M.

## 2. O que mudou

```
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
b159b1d089ae   5 minutes ago   CMD ["uvicorn" "app:api" "--host" "0.0.0.0" …   0B        buildkit.dockerfile.v0
<missing>      5 minutes ago   HEALTHCHECK &{["CMD-SHELL" "python -c \"impo…   0B        buildkit.dockerfile.v0
<missing>      5 minutes ago   EXPOSE [8000/tcp]                               0B        buildkit.dockerfile.v0
<missing>      5 minutes ago   USER loja                                       0B        buildkit.dockerfile.v0
<missing>      5 minutes ago   ENV PATH=/opt/venv/bin:/usr/local/bin:/usr/l…   0B        buildkit.dockerfile.v0
<missing>      5 minutes ago   COPY static/ static/ # buildkit                 7.14kB    buildkit.dockerfile.v0
<missing>      5 minutes ago   COPY app/ app/ # buildkit                       24.5kB    buildkit.dockerfile.v0
<missing>      5 minutes ago   COPY /opt/venv /opt/venv # buildkit             51.6MB    buildkit.dockerfile.v0
<missing>      5 minutes ago   WORKDIR /app                                    0B        buildkit.dockerfile.v0
<missing>      5 minutes ago   RUN /bin/sh -c adduser -D -u 1000 loja # bui…   3.02kB    buildkit.dockerfile.v0
<missing>      3 days ago      CMD ["python3"]                                 0B        buildkit.dockerfile.v0
<missing>      3 days ago      RUN /bin/sh -c set -eux;  for src in idle3 p…   36B       buildkit.dockerfile.v0
<missing>      3 days ago      RUN /bin/sh -c set -eux;   apk add --no-cach…   45.8MB    buildkit.dockerfile.v0
<missing>      3 days ago      ENV PYTHON_SHA256=c2c4321961fab0fb999d66e0ce…   0B        buildkit.dockerfile.v0
<missing>      3 days ago      ENV PYTHON_VERSION=3.12.15                      0B        buildkit.dockerfile.v0
<missing>      3 days ago      ENV GPG_KEY=7169605F62C751356D054A26A821E680…   0B        buildkit.dockerfile.v0
<missing>      3 days ago      RUN /bin/sh -c set -eux;  apk add --no-cache…   916kB     buildkit.dockerfile.v0
<missing>      3 days ago      ENV LANG=C.UTF-8                                0B        buildkit.dockerfile.v0
<missing>      3 days ago      ENV PATH=/usr/local/bin:/usr/local/sbin:/usr…   0B        buildkit.dockerfile.v0
```

Corte principal: sair do slim (~125 MB vazio) para alpine (~60 MB vazio), uns 65 MB.
Depois, nao copiar pip/cache para o estagio final (slim+deps 168 MB vs slim sem pip 155 MB, uns 13 MB).

## 3. Verificacao

```
id -u: 1000
health: healthy
GET /health HTTP 200
GET /api/produtos: [{"id":1,"nome":"Caneca DevOps na Prática","descricao":"Cerâmica, 350 ml: 'funciona na minha máquina'","preco":39.9,"estoque":25,"criado_em":"2026-10-04 22:53:22"},{"id":2,"nome":"Camiseta UFLA Computação","descricao":"Algodão, tamanhos P a GG","preco":59.9,"estoque":40,"criado_em":"2026-10-04 22:53:22"},{"id":3,"nome":"Adesivo Docker","descricao":"Vinil, 8 cm, resistente a água","preco":4.5,"estoque":200,"criado_em":"2026-10-04 22:53:22"},{"id":4,"nome":"Adesivo Kubernetes","descricao":"Vinil, 8 cm, resistente a água","preco":4.5,"estoque":180,"criado_em":"2026-10-04 22:53:22"},{"id":5,"nome":"Moletom DCC","descricao":"Moletom com capuz, cinza, bordado","preco":149.9,"estoque":12,"criado_em":"2026-10-04 22:53:22"},{"id":6,"nome":"Garrafa térmica 500 ml","descricao":"Inox, mantém a temperatura por 8 h","preco":89.0,"estoque":30,"criado_em":"2026-10-04 22:53:22"},{"id":7,"nome":"Mousepad Terminal","descricao":"Estampa de terminal Linux, 40 x 20 cm","preco":34.9,"estoque":50,"criado_em":"2026-10-04 22:53:22"},{"id":8,"nome":"Caderno Postmortem","descricao":"Pautado, 96 folhas, capa dura","preco":29.9,"estoque":60,"criado_em":"2026-10-04 22:53:22"},{"id":9,"nome":"Boné Site Reliability","descricao":"Aba curva, ajustável","preco":49.9,"estoque":18,"criado_em":"2026-10-04 22:53:22"},{"id":10,"nome":"Chaveiro YAML","descricao":"Acrílico, 'indentação importa'","preco":9.9,"estoque":120,"criado_em":"2026-10-04 22:53:22"},{"id":11,"nome":"Livro: Engenharia de Software Contínua","descricao":"Edição da turma, 280 páginas","preco":79.0,"estoque":8,"criado_em":"2026-10-04 22:53:22"},{"id":12,"nome":"Kit de adesivos CI/CD","descricao":"Dez adesivos sortidos","preco":19.9,"estoque":75,"criado_em":"2026-10-04 22:53:22"}]

loja

real	0m0.640s
user	0m0.016s
sys	0m0.011s
```
