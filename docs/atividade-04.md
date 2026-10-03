# Atividade 4 — Containerizar a aplicação

## 1. Tamanho da imagem: antes e depois

A imagem foi construída já com a base `python:3.12-alpine` para garantir o atendimento
da meta de 150 MB. Os números de referência abaixo usam as medições do `docs/aplicacao.md`,
que documentam o que aconteceria com `python:3.12-slim`:

| Versão | Base | Tamanho |
|--------|------|---------|
| Referência (slim + deps) | `python:3.12-slim` | 168 MB |
| Final (alpine + multi-stage) | `python:3.12-alpine` | 106 MB |

```
$ docker image inspect --format '{{.Size}}' ufla-shop:1.0 | numfmt --to=si
106M

IMAGE           ID             DISK USAGE   CONTENT SIZE
ufla-shop:1.0   ea9a7e750406        105MB             0B
```

## 2. O que mudou e quanto economizou

**Troca de base: `python:3.12-slim` → `python:3.12-alpine`**
- `slim` sozinho: 125 MB; com dependências: 168 MB — ultrapassa a meta de 150 MB.
- `alpine` sozinho: 60 MB; com dependências: 106 MB — 62 MB a menos que o slim.
- Todas as dependências do `requirements.txt` têm wheels para musl, então nenhuma
  compilação foi necessária.

**Build multi-stage**
- O estágio `builder` instala as dependências com `pip`.
- O estágio final copia apenas `site-packages` e o binário `uvicorn`, sem `pip`
  nem caches de instalação, sem ferramenta de build na imagem de produção.

**`.dockerignore`**
- Exclui `.git`, `.venv`, `__pycache__`, `tests`, `*.db`, `.env` e outros arquivos
  que não são necessários em tempo de execução, reduzindo o contexto de build e
  garantindo que nenhum dado sensível entre na imagem.

## 3. Saída dos comandos de verificação

```
# Tamanho
$ docker image inspect --format '{{.Size}}' ufla-shop:1.0 | numfmt --to=si
106M

# Usuário não-root
$ docker run --rm ufla-shop:1.0 id -u
1000

# Healthcheck
$ docker inspect --format '{{.State.Health.Status}}' loja
healthy

# Resposta da API
$ curl -s localhost:8080/health
{"status":"ok","versao":"1.0.0"}

$ curl -s localhost:8080/api/produtos | head -c 200
[{"id":1,"nome":"Caneca DevOps na Prática","descricao":"Cerâmica, 350 ml: 'funciona na minha máquina'","preco":39.9,"estoque":25,"criado_em":"2026-10-03 13:51:58"},{"id":2,"nome":"Camiseta UFLA Com...

# Tempo de parada (docker stop)
$ time docker stop loja
real    0m0.848s
user    0m0.019s
sys     0m0.013s
```

## 4. Por que o HEALTHCHECK consulta /health e não /ready?

O `HEALTHCHECK` do Docker verifica se o **processo está vivo** (_liveness_): a rota
`/health` responde sempre com 200, sem tocar em banco ou cache, exatamente para isso.

A rota `/ready` (_readiness_) verifica se a aplicação **pode receber tráfego** — ela
checa banco e cache, retornando 503 se algum serviço estiver indisponível. Usar `/ready`
no `HEALTHCHECK` faria o Docker reiniciar o container toda vez que o banco ou o Redis
ficassem fora do ar, mesmo que a aplicação em si estivesse saudável, que é o comportamento
errado para _liveness_.
