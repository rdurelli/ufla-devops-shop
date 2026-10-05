# Atividade 04: imagem Docker

## 1. Tamanho antes e depois

A primeira versão que funcionou foi reconstruída com a tag temporária
`ufla-shop:initial`, usando o Dockerfile anterior à otimização. A imagem final
foi construída com a tag `ufla-shop:1.0`.

| Versão | `docker image inspect --format '{{.Size}}'` | `numfmt --to=si` | `docker images` |
|---|---:|---:|---:|
| Inicial, antes da otimização | `156101487` bytes | `157M` | `156MB` |
| Final | `98985606` bytes | `99M` | `99MB` |

A redução total foi de `57115881` bytes, aproximadamente `57,1 MB` na medida
do `docker image inspect`.

## 2. Alterações e camadas

O `docker history` mostrou estas camadas equivalentes nas duas imagens:

| Camada | Inicial | Final | Redução observada |
|---|---:|---:|---:|
| `COPY /opt/venv /opt/venv` | `57,1MB` | `12,4MB` | aproximadamente `44,7MB` |
| `COPY app ./app` | `111kB` | `111kB` | `0` |
| `COPY static ./static` | `24,6kB` | `24,6kB` | `0` |
| criação do usuário e diretório de dados | `49,2kB` | `49,2kB` | `0` |

A maior economia veio do virtualenv. A primeira versão instalava todas as
dependências de `requirements.txt`, incluindo `psycopg[binary]` e `redis`,
embora o container desta atividade use apenas SQLite e cache em memória. A
versão final instala somente `fastapi` e `uvicorn`, que são necessários para
este modo de execução.

Também foram aplicadas estas otimizações na mesma camada de instalação:

- `python:3.12-alpine` foi usado como imagem base pequena;
- o build foi dividido em dois estágios, e o estágio final recebe apenas o
  virtualenv pronto e os arquivos necessários da aplicação;
- `--no-cache-dir` impede que o pip mantenha seu cache;
- `--no-compile` evita gerar bytecode durante a instalação;
- `pip` e `setuptools` são removidos depois da instalação, pois não são
  necessários em runtime;
- `.dockerignore` impede o envio de `.git`, `.venv`, testes, bancos SQLite,
  caches e arquivos `.env` no contexto do build.

O `docker history` permite medir diretamente a redução da camada do virtualenv.
Como várias mudanças foram feitas nessa mesma etapa de instalação, a economia
individual de cada uma delas não é separada pelo Docker; a comparação confiável
é a redução da camada e a redução total da imagem. As demais camadas da
aplicação permaneceram iguais.

## 3. Saída da verificação

Os comandos da Parte 2 produziram os resultados relevantes abaixo:

```text
$ docker run --rm ufla-shop:1.0 id -u
100

$ docker inspect --format '{{.State.Health.Status}}' loja
healthy

$ time docker stop loja
loja
docker stop loja  0,03s user  0,01s system  11% cpu  0,390 total
```

As consultas HTTP também responderam corretamente:

```text
$ curl -s localhost:8000/health
{"status":"ok","versao":"1.0.0"}

$ curl -s localhost:8000/api/produtos | head -c 200
```

O endpoint `/api/produtos` devolveu os 12 produtos iniciais.

## 4. `HEALTHCHECK` e `/health`

O `HEALTHCHECK` consulta `/health` porque essa rota verifica somente se o processo HTTP está vivo e não depende de PostgreSQL ou Redis. A rota `/ready` verifica banco e cache e pode retornar `503` quando essas dependências estão indisponíveis, mesmo que a aplicação esteja viva.