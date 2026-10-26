# Atividade 4 — Containerizar a aplicação

## Imagem antes e depois

As duas imagens foram construídas com Docker no Fedora 44/WSL2:

```text
Imagem             Tamanho descompactado
ufla-shop:baseline 37M
ufla-shop:1.0      33M
```

A versão final ficou abaixo da meta de 150 MB.

## O que foi otimizado

As duas versões usam `python:3.12-alpine` e build multi-stage. O estágio
`builder` instala as dependências em um ambiente virtual; a imagem final recebe
somente esse ambiente e os diretórios necessários para executar a loja.

Na versão final, `pip` e `setuptools` são removidos do ambiente virtual, a
instalação usa `--no-cache-dir`, e o `COPY` foi restrito a `app/` e `static/`.
O `.dockerignore` exclui Git, ambientes virtuais, caches, testes, bancos locais,
dados e arquivos de ambiente. O tamanho medido caiu de 37M para 33M, uma
redução de aproximadamente 4M.

## Verificação da imagem

```text
$ docker run --rm ufla-shop:1.0 id -u
100

$ docker inspect --format '{{.State.Health.Status}}' loja
healthy

$ curl -s localhost:8000/health
{"status":"ok","versao":"1.0.0"}

$ curl -s localhost:8000/api/produtos | python -c '...'
12

$ time docker stop loja
loja
real 0m0.480s
```

O `Dockerfile` usa `CMD` na forma exec, então o Uvicorn recebe os sinais do
Docker diretamente. A imagem executa como UID `100`, declara `HEALTHCHECK` e
publica a porta 8000.

## Conteúdo do runtime

O runtime contém somente a aplicação e os arquivos estáticos:

```text
/app/app
/app/static
```

Não entram na imagem `.git`, `.venv`, `tests`, `*.db`, `.env`, `dados` ou caches
do projeto.

## Por que `/health` e não `/ready`?

O `HEALTHCHECK` consulta `/health` porque ele verifica apenas se o processo está
vivo e não depende de PostgreSQL ou Redis, que só entram na Atividade 5. O
`/ready` verifica dependências externas e poderia marcar como indisponível um
container saudável no modo autônomo desta atividade.