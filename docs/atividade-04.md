# Atividade 4 — Containerizar a aplicação

**Aluno:** Filipe Rezende Silva
**GitHub:** filipesilva07
**Repositório:** https://github.com/filipesilva07/ufla-devops-shop
**Branch:** atividade-04

## 1. Objetivo

Containerizar a aplicação `ufla-devops-shop` utilizando Docker, com imagem otimizada, construção multi-stage, execução sem privilégios de root, HEALTHCHECK e encerramento rápido do contêiner.

A aplicação foi executada em modo autônomo, utilizando SQLite e cache em memória, sem depender de serviços externos.

## 2. Construção das imagens

Foram construídas duas imagens Docker para comparar os tamanhos e avaliar as otimizações realizadas.

### 2.1. Imagem inicial

A primeira imagem foi construída utilizando `python:3.12-slim`, com instalação direta das dependências de execução.

Comando utilizado:

```bash
docker build -f Dockerfile.inicial -t ufla-shop:inicial .
```

Resultado: construção concluída com sucesso.

Essa versão foi utilizada como referência de tamanho para comparação com a imagem otimizada.

### 2.2. Imagem otimizada

A imagem final foi construída utilizando `python:3.12-alpine` e duas etapas (multi-stage build):

1. **Builder:** instalação das dependências presentes em `requirements.txt`.
2. **Imagem final:** cópia das dependências instaladas, do diretório `app/` e dos arquivos de `static/`.

A imagem também utiliza um usuário sem privilégios administrativos, HEALTHCHECK e CMD na forma exec.

Comando utilizado:

```bash
docker build -t ufla-shop:1.0 .
```

Resultado: construção concluída com sucesso em aproximadamente 42,2 segundos.

## 3. Tamanho das imagens e otimização

Os tamanhos foram obtidos no mesmo ambiente Docker utilizando:

```bash
docker image inspect --format '{{.Size}} bytes' ufla-shop:inicial
docker image inspect --format '{{.Size}} bytes' ufla-shop:1.0
```

Resultados:

```text
Imagem inicial:    59598090 bytes
Imagem otimizada:  30332775 bytes
```

### Comparação

| Indicador | Resultado |
|---|---:|
| Imagem inicial (Python Slim) | 59,60 MB |
| Imagem otimizada (Alpine multi-stage) | 30,33 MB |
| Redução absoluta | 29,27 MB |
| Redução percentual | 49,1% |
| Limite exigido na atividade | 150 MB |
| Resultado | Aprovado |

A imagem otimizada ficou aproximadamente 49,1% menor que a imagem inicial e abaixo do limite de 150 MB.

### Otimizações realizadas

- **Python Alpine:** utilização de uma distribuição Linux compacta, reduzindo o tamanho da imagem base.
- **Multi-stage build:** separação entre a instalação das dependências e a montagem da imagem final.
- **Dependências de execução:** instalação apenas dos pacotes necessários, definidos em `requirements.txt`.
- **.dockerignore:** exclusão de `.git`, `.venv`, testes, caches, arquivos `.db` e `.env` do contexto de construção.
- **Cópia seletiva:** inclusão apenas dos diretórios `app/` e `static/` na imagem final.

A redução de 29,27 MB representa o efeito combinado das diferenças entre as duas construções. Não foram realizadas medições individuais da economia de cada alteração.

### Histórico das camadas

Foi executado:

```bash
docker history ufla-shop:1.0
```

Principais camadas observadas:

| Camada | Tamanho |
|---|---:|
| Dependências copiadas do builder | 44,4 MB |
| Código da aplicação | 115 kB |
| Arquivos estáticos | 24,6 kB |
| Criação de usuário e ajuste de permissões | 168 kB |

Os valores do histórico representam tamanhos de camadas e não devem ser confundidos com a medida retornada por `docker image inspect`.

## 4. Testes de funcionamento

### 4.1. Inicialização do contêiner

Comando:

```bash
docker run -d --name loja -p 8000:8000 ufla-shop:1.0
```

O Docker criou o contêiner com sucesso.

Em seguida, foi executado:

```bash
docker ps
```

Resultado observado:

```text
IMAGE           STATUS                    PORTS
ufla-shop:1.0   Up 40 seconds (healthy)   0.0.0.0:8000->8000/tcp
```

O contêiner `loja` permaneceu em execução e apresentou status saudável.

### 4.2. Endpoint /health

Comando:

```bash
curl -s http://localhost:8000/health
```

Resultado:

```json
{"status":"ok","versao":"1.0.0"}
```

O endpoint respondeu corretamente, confirmando o funcionamento da aplicação.

### 4.3. Catálogo de produtos

Comando:

```bash
curl -s http://localhost:8000/api/produtos | python3 -m json.tool
```

Resultado: a API retornou corretamente os 12 produtos cadastrados no catálogo.

### 4.4. Execução sem root

Comando:

```bash
docker run --rm ufla-shop:1.0 id -u
```

Resultado:

```text
100
```

Como o UID retornado foi `100`, diferente de `0`, foi confirmado que a imagem utiliza um usuário sem privilégios de root.

### 4.5. HEALTHCHECK

O Dockerfile contém um HEALTHCHECK que utiliza Python e `urllib.request` para consultar o endpoint:

```text
http://127.0.0.1:8000/health
```

O comando `docker ps` confirmou o estado:

```text
Up (healthy)
```

O HEALTHCHECK foi implementado sem a necessidade de instalar `curl` na imagem.

### 4.6. Tempo de encerramento

Comando:

```bash
time docker stop loja
```

Resultado:

```text
loja

real    0m1.208s
user    0m0.026s
sys     0m0.040s
```

O contêiner foi encerrado em aproximadamente 1,208 segundo, atendendo ao requisito de parada em menos de 2 segundos.

O Dockerfile utiliza CMD na forma exec:

```dockerfile
CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
```

Essa configuração permite que o Uvicorn receba diretamente os sinais de encerramento enviados pelo Docker.

## 5. Por que utilizar /health em vez de /ready?

O endpoint `/health` verifica se o processo da aplicação está vivo, sem depender da disponibilidade do banco de dados ou do cache. Já o endpoint `/ready` verifica se a aplicação está pronta para receber requisições, incluindo a conectividade com esses serviços, podendo retornar erro mesmo quando o processo continua funcionando.

## 6. Conclusão

A aplicação `ufla-devops-shop` foi containerizada com sucesso utilizando Docker, uma imagem multi-stage baseada em Alpine, usuário sem privilégios administrativos, HEALTHCHECK e inicialização em modo autônomo.

A imagem otimizada apresentou tamanho de 30,33 MB, representando uma redução de aproximadamente 49,1% em relação à imagem inicial de 59,60 MB.

Os testes confirmaram o funcionamento da API, o retorno dos 12 produtos, o estado saudável do contêiner, a execução sem root e o encerramento em menos de 2 segundos.

Dessa forma, os requisitos técnicos testados na Atividade 4 foram atendidos.
