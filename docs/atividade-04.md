# Atividade 4 — Containerizar a aplicação

## 1. Tamanho antes e depois

A primeira versão funcional usava `python:3.12-slim` nos dois estágios; a versão
final usa `python:3.12-alpine`.

```text
REPOSITORY   TAG       IMAGE ID       SIZE
ufla-shop    1.0       0c9b87d3b10e   107MB
ufla-shop    inicial   24aacaafb225   173MB
```

## 2. O que mudou

A primeira versão utilizava `python:3.12-slim` nos dois estágios e ocupava
173.079.282 bytes.

1. Troquei `python:3.12-slim` por `python:3.12-alpine` nos estágios de build e
   execução. O tamanho caiu para 107.191.178 bytes, uma economia de 65.888.104
   bytes (aproximadamente 65,9 MB).

2. Ajustei o `.dockerignore` para excluir os diretórios `__pycache__` de forma
   recursiva. O tamanho caiu para 107.155.573 bytes, uma economia adicional de
   35.605 bytes (aproximadamente 35,6 kB).

A imagem final ficou 65.923.709 bytes menor que a primeira versão, uma economia
total de aproximadamente 65,9 MB.

## 3. Comandos de verificação

```text
$ docker run --rm ufla-shop:1.0 id -u
100

$ docker inspect --format '{{.State.Health.Status}}' loja
healthy

$ time docker stop loja
loja

real    0m0,402s
user    0m0,014s
sys     0m0,022s
```

## 4. Por que `/health` e não `/ready`?

O `HEALTHCHECK` consulta `/health` porque precisa verificar se o processo está vivo sem depender do banco ou do cache. A rota `/ready` verifica essas dependências e poderia marcar como `unhealthy` um processo saudável durante uma indisponibilidade externa.
