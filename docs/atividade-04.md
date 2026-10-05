# Atividade 4 — Containerizar a aplicação

## 1. Tamanho das Imagens

Saída do `docker images` comparando a versão funcional 1 (base `python:3.12-slim` em estágio único) e a versão final otimizada (base `python:3.12-alpine` em multi-stage):

```bash
$ docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -E "REPOSITORY|ufla-shop"
REPOSITORY:TAG            IMAGE ID       SIZE
ufla-shop:antes           a9d72bb18a92   246MB
ufla-shop:1.0             897bae60bed4   125MB
```

Comparativo de tamanho inspecionado (`docker image inspect --format '{{.Size}}' <imagem> | numfmt --to=si`):

- **Primeira versão funcional (`ufla-shop:antes`)**: 60 MB
- **Versão final otimizada (`ufla-shop:1.0`)**: 29 MB

A imagem final foi redizida em aproximadamente **121 MB**.

---

## 2. O que mudou entre uma versão e outra e economia por camada

A análise das camadas via `docker history` demonstra as seguintes alterações e ganhos:

1. **Troca da imagem base (python:3.12 de `slim` para `alpine`)**:
   - A camada do SO base Debian Trixie pesava ~**133 MB**
   - No Alpine, o `rootfs` e o interpretador do python totaliza ~**56 MB**.

2. **Implementação de Multi-Stage Build**:
   - O processo de instalação de pacotes e o gerenciador `pip` foram destinados para o estágio de `builder`, que preparou o venv.
   - Na versão original em estágio único, o comando `pip install` gerava ~**54 MB** e acumulava arquivos temporários e caches.
   - No estágio final, apenas o venv (`/opt/venv`) limpo foi importado, ocupando **39.8 MB**.

---

## 3. Saída dos Comandos de Verificação

### 3.1. Execução como usuário não-root

```bash
$ docker run --rm ufla-shop:1.0 id -u
1000
```

### 3.2. Status do HEALTHCHECK

```bash
$ docker run -d --name loja -p 8000:8000 ufla-shop:1.0
$ sleep 10 && docker inspect --format '{{.State.Health.Status}}' loja
healthy
```

### 3.3. Verificação das rotas `/health` e `/api/produtos`

```bash
$ curl -s localhost:8000/health
{"status":"ok","versao":"1.0.0"}

$ curl -s localhost:8000/api/produtos | head -c 200
[{"id":1,"nome":"Caneca DevOps na Prática","descricao":"Cerâmica, 350 ml: 'funciona na minha máquina'","preco":39.9,"estoque":25,"criado_em":"2026-09-27 14:57:52"},{"id":2,"nome":"Camiseta UFLA Com
```

### 3.4. Encerramento gracioso em menos de 2 segundos

```bash
$ time docker stop loja
loja

real    0m0,617s
user    0m0,012s
sys     0m0,013s
```

---

## 4. Por que o HEALTHCHECK consulta `/health` e não `/ready`?

Porque a ideia do `HEALTHCHECK` é verificar se o processo do contêiner está *online* (rodando). Isso significa que queremos o status **específico do servidor**, descontando outros serviços. Em `aplicação.md` é dito que `/ready` retorna `STATUS 200` somente se o banco/cache estiverem comunicando normalmente com o servidor, caso contrário, apesar do processo (portanto o contêiner) estar funcional receberíamos a respsota `unhealthy`.
