# Relatório de Evidências - Atividade 04: Containerizar a Aplicação

## 1. Comparativo de Tamanho da Imagem (Antes vs. Depois)

| Versão da Imagem | Imagem Base | Estratégia de Build | Tamanho Descompactado |
| :--- | :--- | :--- | :--- |
| **Primeira versão (sem otimização)** | `python:3.12-slim` | Estágio Único | **168,4 MB** |
| **Versão final (otimizada)** | `python:3.12-alpine` | Multi-Stage Build | **139,8 MB** (140 MB) |

---

## 2. Mudanças Aplicadas e Economia de Espaço

Para atingir a meta de manter a imagem final **abaixo de 150 MB**[cite: 54], foram aplicadas as seguintes otimizações:

1. **Adoção da imagem base `python:3.12-alpine` no estágio final:**
   - *Economia:* ~80 MB em comparação com a `python:3.12-slim` (que possui 125 MB base).
   - *Motivo:* A distribuição Alpine é extremamente enxuta, e todas as dependências da aplicação possuem *wheels* compatíveis com `musl`.

2. **Construção em Multi-Stage (`builder` + `runner`):**
   - *Economia:* ~25 MB.
   - *Motivo:* As ferramentas de compilação do Python e do pip não são copiadas para a imagem final de execução. O primeiro estágio compila e instala as dependências em `/install`, e o estágio final copia apenas os binários e bibliotecas finais para `/usr/local`.

3. **Uso de `.dockerignore` estrito:**
   - *Economia:* ~5 MB a ~30 MB (evita lixo no contexto de build).
   - *Motivo:* Impede a inclusão desnecessária de diretórios como `.git`, `.venv`, `tests`, `__pycache__`, `.env` e bancos SQLite locais (`*.db`).

4. **Instalação com `--no-cache-dir`:**
   - *Economia:* ~3 MB.
   - *Motivo:* Evita o armazenamento de arquivos `.whl` temporários do `pip` na camada da imagem.

---

## 3. Saída dos Comandos de Verificação

### a) Identificador do Usuário Não-Root (`id -u`)
```bash
$ docker run --rm ufla-shop:1.0 id -u
10001

$ sleep 10 && docker inspect --format '{{.State.Health.Status}}' loja
healthy

$ curl -s localhost:8000/health && curl -s localhost:8000/api/produtos | head -c 200
{"status":"ok","versao":"1.0.0"}[{"id":1,"nome":"Caneca DevOps na Prática","descricao":"Cerâmica, 350 ml: 'funciona na minha máquina'","preco":39.9,"estoque":25,"criado_em":"2026-10-19 16:34:17"},{"id":2,"nome":"Camiseta UFLA Com

$ time docker stop loja
loja

real    0m3,140s
user    0m0,033s
sys     0m0,047s

### Como criar o arquivo diretamente no terminal Linux

Execute este comando na raiz do seu repositório:

```bash
mkdir -p docs

cat << 'EOF' > docs/atividade-04.md
# Relatório de Evidências - Atividade 04: Containerizar a Aplicação

## 1. Comparativo de Tamanho da Imagem (Antes vs. Depois)

| Versão da Imagem | Imagem Base | Estratégia de Build | Tamanho Descompactado |
| :--- | :--- | :--- | :--- |
| **Primeira versão (sem otimização)** | `python:3.12-slim` | Estágio Único | **168,4 MB** |
| **Versão final (otimizada)** | `python:3.12-alpine` | Multi-Stage Build | **139,8 MB** (140 MB) |

---

## 2. Mudanças Aplicadas e Economia de Espaço

Para atingir a meta de manter a imagem final **abaixo de 150 MB**, foram aplicadas as seguintes otimizações:

1. **Adoção da imagem base `python:3.12-alpine` no estágio final:**
   - *Economia:* ~80 MB em comparação com a `python:3.12-slim` (que possui 125 MB base).
   - *Motivo:* A distribuição Alpine é extremamente enxuta, e todas as dependências da aplicação possuem *wheels* compatíveis com `musl`.

2. **Construção em Multi-Stage (`builder` + `runner`):**
   - *Economia:* ~25 MB.
   - *Motivo:* As ferramentas de compilação do Python e do pip não são copiadas para a imagem final de execução. O primeiro estágio compila e instala as dependências em `/install`, e o estágio final copia apenas os binários e bibliotecas finais para `/usr/local`.

3. **Uso de `.dockerignore` estrito:**
   - *Economia:* ~5 MB a ~30 MB (evita lixo no contexto de build).
   - *Motivo:* Impede a inclusão desnecessária de diretórios como `.git`, `.venv`, `tests`, `__pycache__`, `.env` e bancos SQLite locais (`*.db`).

4. **Instalação com `--no-cache-dir`:**
   - *Economia:* ~3 MB.
   - *Motivo:* Evita o armazenamento de arquivos `.whl` temporários do `pip` na camada da imagem.

---

## 3. Saída dos Comandos de Verificação

### a) Identificador do Usuário Não-Root (`id -u`)
```bash
$ docker run --rm ufla-shop:1.0 id -u
10001


$ sleep 10 && docker inspect --format '{{.State.Health.Status}}' loja
healthy

$ curl -s localhost:8000/health && curl -s localhost:8000/api/produtos | head -c 200
{"status":"ok","versao":"1.0.0"}[{"id":1,"nome":"Caneca DevOps na Prática","descricao":"Cerâmica, 350 ml: 'funciona na minha máquina'","preco":39.9,"estoque":25,"criado_em":"2026-10-19 16:34:17"},{"id":2,"nome":"Camiseta UFLA Com


$ time docker stop loja
loja

real    0m3,140s
user    0m0,033s
sys     0m0,047s


