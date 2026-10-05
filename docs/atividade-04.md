# Atividade 04 — Containerização da aplicação

## 1. Tamanho das imagens

| Versão | Tamanho |
|---|---:|
| Primeira versão | 170 MB |
| Versão final | 137 MB |

A primeira versão ficou com 170 MB. Depois das alterações, a imagem final ficou com 137 MB, reduzindo 33 MB.

## 2. Alterações realizadas

Na primeira versão foi utilizada a imagem `python:3.12-slim`, com as dependências instaladas direto na imagem final.

Depois, foi utilizado build multi-stage e a imagem foi alterada para `python:3.12-alpine`.

Também foram copiados para a imagem final apenas os arquivos necessários para rodar a aplicação.

Com essas alterações, a imagem passou de 170 MB para 137 MB.

## 3. Verificações

### Usuário não-root

```text
$ docker run --rm ufla-shop:1.0 id -u
1000
```

### Healthcheck

```text
$ docker inspect --format '{{.State.Health.Status}}' loja
healthy
```

### Tempo de parada

```text
$ time docker stop loja
loja

real    0m0,372s
user    0m0,006s
sys     0m0,011s
```

### Endpoint de health

```text
$ curl -s localhost:8000/health
{"status":"ok","versao":"1.0.0"}
```

## 4. Por que o HEALTHCHECK utiliza /health e não /ready?

O `/health` verifica se a aplicação está funcionando e respondendo. Já o `/ready` verifica se ela está pronta para receber requisições e pode depender de outros serviços.