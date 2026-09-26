# Atividade 04 - Containerizar a aplicação

## 1. Tamanho da imagem

A primeira versão  foi construída utilizando `python:3.12-slim` com build multi-stage e apenas as dependências de execução presentes em `requirements.txt`.

| Versão | Tamanho |
|---|---:|
| Primeira versão | 56 MB |
| Versão final | 56 MB |

O comando utilizado para verificar o tamanho da versão:

```bash
docker image inspect --format '{{.Size}}' ufla-shop:1.0 | numfmt --to=si
```

Saída:

```text
56M
```
---

## 2. Alterações e análise das camadas

Utilizei um build multi-stage. No primeiro estágio, chamado `builder`, as dependências presentes em `requirements.txt` são instaladas separadamente. No estágio final, apenas essas dependências e os arquivos necessários para executar a aplicação são copiados.

Isso evita levar para a imagem final arquivos utilizados apenas durante o processo de build.

O `.dockerignore` também impede o envio de arquivos desnecessários ao contexto de build, incluindo:

- `.git`
- `.venv`
- `__pycache__`
- `tests`
- `*.db`
- `.env`
- `.pytest_cache`
- `.github`

Na versão final também foi criado o usuário não-root `appuser`, com UID `10001`. O diretório `/app` pertence a esse usuário, permitindo que a aplicação escreva seus arquivos, incluindo o banco SQLite criado em tempo de execução, sem que o processo precise executar como `root`.

A análise com `docker history` mostrou que as principais camadas adicionadas pela aplicação foram:

```text
COPY /install /usr/local    45.8MB
COPY app/ ./app/             106kB
COPY static/ ./static/       24.6kB
chown /app                    123kB
```

A maior parte do tamanho adicional corresponde às dependências Python instaladas em `/usr/local`.

A primeira versão funcional já possuía aproximadamente 56 MB e a versão final permaneceu com aproximadamente 56 MB.

Isso aconteceu porque a primeira versão já utilizava `python:3.12-slim`, build multi-stage, somente as dependências de execução e cópia seletiva de `app/` e `static/`. As alterações posteriores foram principalmente para segurança, monitoramento da saúde do container e encerramento correto do processo.

---

## 3. Verificações

### 3.1 Usuário não-root

Foi executado:

```bash
docker run --rm ufla-shop:1.0 id -u
```

Saída:

```text
10001
```

Como o UID retornado é diferente de `0`, a aplicação está sendo executada por um usuário não-root.

---

### 3.2 HEALTHCHECK

Após iniciar o container e aguardar o healthcheck, foi executado:

```bash
docker inspect --format '{{.State.Health.Status}}' loja
```

Saída:

```text
healthy
```

O `HEALTHCHECK` consulta internamente:

```text
http://127.0.0.1:8000/health
```

A verificação utiliza o próprio Python com `urllib.request`, evitando a necessidade de instalar ferramentas adicionais como `curl` dentro da imagem.

---

### 3.3 Endpoint `/health`

O endpoint foi verificado com:

```bash
curl -s localhost:8000/health
```

Saída:

```json
{"status":"ok","versao":"1.0.0"}
```

A aplicação respondeu corretamente ao endpoint de saúde.

---

### 3.4 Endpoint `/api/produtos`

A quantidade de produtos retornados pela aplicação foi verificada com:

```bash
curl -s localhost:8000/api/produtos | python3 -m json.tool | grep '"id"' | wc -l
```

Saída:

```text
12
```

Portanto, o endpoint `/api/produtos` retornou os 12 produtos esperados.

---

### 3.5 Tempo de encerramento

O tempo necessário para parar o container foi medido com:

```bash
time docker stop loja
```

Saída:

```text
loja

real    0m0.940s
user    0m0.009s
sys     0m0.037s
```

O container encerrou em aproximadamente `0,940 s`, portanto abaixo do limite de 2 segundos.

O `CMD` foi declarado na forma exec:

```dockerfile
CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
```

Dessa forma, o Uvicorn recebe diretamente o `SIGTERM` enviado pelo Docker e consegue realizar o encerramento corretamente.

---

## 4. Por que o HEALTHCHECK consulta `/health` e não `/ready`?

O `/health` verifica se o processo da aplicação está vivo e consegue responder, e é utilizado para determinar a saúde do container. O `/ready` representa a prontidão da aplicação para receber tráfego.
