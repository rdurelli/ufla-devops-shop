# Atividade 04 — Containerizar a aplicação

## 1. Comparação do Tamanho da Imagem

Para analisar o impacto das otimizações na imagem da aplicação, realizou-se a construção a partir de duas estratégias distintas de `Dockerfile` (`Dockerfile.old` sem otimizações e `Dockerfile` otimizado).

| Imagem | Tamanho Descompactado | Redução |
| :--- | :---: | :---: |
| **Antes da otimização** (`Dockerfile.old`) | `1.7 GB` | — |
| **Depois da otimização** (`Dockerfile`) | `131 MB` | **~92.3%** |

### Comandos Utilizados para Medição

**1. Construção e inspeção da versão pré-otimização:**
```bash
docker build -f Dockerfile.old -t ufla-shop:antes .
docker image inspect --format='{{.Size}}' ufla-shop:antes | numfmt --to=si
# Resultado obtido: 1.7G
```

**2. Construção e inspeção da versão otimizada (final):**

```bash
docker build -f Dockerfile -t ufla-shop:1.0 .
docker image inspect --format='{{.Size}}' ufla-shop:1.0 | numfmt --to=si
# Resultado obtido: 131M (atende ao requisito de ficar abaixo de 150 MB)
```

## 2. Otimizações e Cortes Realizados

Para atingir a meta de tamanho reduzido e manter a segurança, foram aplicadas as seguintes otimizações:

- Build Multi-Stage: As dependências de compilação são isoladas no estágio builder. Apenas os pacotes e arquivos necessários para a execução são copiados para a imagem final (runtime).

- Imagem Base Enxuta (python:3.12-alpine): Adotou-se a distribuição Alpine em ambos os estágios, reduzindo drasticamente a pegada inicial do sistema operacional.

- Limpeza de Caches: Uso da flag --no-cache-dir no pip para evitar armazenar arquivos de instalação temporários e da variável PYTHONDONTWRITEBYTECODE=1 para evitar a geração de arquivos .pyc.
 
- Filtro Rigoroso no .dockerignore: Exclusão explícita de repositório Git, ambientes virtuais (venv), diretórios de testes, bancos de dados locais (*.db), variáveis de ambiente (.env), documentação e configurações de IDEs/compilação.

- Execução Não-Root: Criação do usuário dedicado appuser (UID 10001). O diretório /app recebeu permissão de escrita (chown) para permitir a criação e manipulação do banco de dados SQLite (loja.db) em runtime.

## 3. Verificações de Execução e Saúde

Os testes a seguir validam os requisitos de segurança, verificação de saúde (healthcheck) e encerramento gracioso (graceful shutdown).

```bash
# 1. Subir a aplicação em container
docker run -d --name loja -p 8000:8000 ufla-shop:1.0

# 2. Verificar se o processo executa como não-root (UID != 0)
docker run --rm ufla-shop:1.0 id -u
# Saída esperada: 10001

# 3. Aguardar o tempo do intervalo e checar o status de saúde
sleep 10 && docker inspect --format='{{.State.Health.Status}}' loja
# Saída esperada: healthy

# 4. Validar os endpoints HTTP da aplicação
curl -s http://localhost:8000/health
curl -s http://localhost:8000/api/produtos | head -c 200

# 5. Medir o tempo de encerramento do container
time docker stop loja
```


**Resultados observados:**

- UID do processo: `10001 (não-root)`
- Health Status: `healthy`
- Tempo de `docker stop`:
    - `real    0m0,372s`
    - `user    0m0,011s`
    - `sys     0m0,016s`

Nota: O tempo de parada inferior a 1 segundo é garantido pelo uso do CMD na sintaxe JSON/exec (CMD ["uvicorn", ...]), garantindo que o Uvicorn seja o PID 1 no container e receba o sinal SIGTERM diretamente do Docker

## Por que o HEALTHCHECK consulta `/health` e não `/ready`?

O HEALTHCHECK nativo do Docker é utilizado para verificar a vitalidade (liveness) do container, ou seja, se o processo da aplicação continua em execução e capaz de responder a requisições HTTP básicas. A rota /health realiza essa verificação sem consultar dependências externas.

A rota /ready, por outro lado, verifica a prontidão (readiness) do serviço, confirmando se dependências como banco de dados (PostgreSQL) e cache (Redis) estão operacionais para processar transações.

Se o HEALTHCHECK do Docker consultasse /ready, uma indisponibilidade temporária no banco de dados faria o Docker marcar o container como unhealthy, provocando o reinício do processo da aplicação. Isso não resolveria o problema do banco e criaria reinícios desnecessários. Em arquiteturas com orquestradores (como Kubernetes), /ready é usada para decidir se a instância deve receber tráfego, enquanto /health (ou liveness probe) determina se o container deve ser reiniciado.