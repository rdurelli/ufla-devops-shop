# syntax=docker/dockerfile:1

# Instala as dependencias em um estagio separado para nao levar ferramentas
# de build, caches ou arquivos temporarios para a imagem final.
FROM python:3.12-alpine AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# A mesma base Alpine garante compatibilidade das dependencias binárias
# instaladas no estagio anterior.
FROM python:3.12-alpine AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# UID fixo e sem shell/home: o processo da aplicacao nao roda como root.
RUN addgroup -S -g 10001 appuser \
    && adduser -S -D -H -u 10001 -G appuser appuser \
    && chown appuser:appuser /app

# Copia somente as dependencias de runtime do estagio de build.
COPY --from=builder /install /usr/local

# A aplicacao precisa dos fontes e dos arquivos estaticos da interface.
COPY --chown=appuser:appuser app/ ./app/
COPY --chown=appuser:appuser static/ ./static/

# O SQLite usa loja.db dentro de /app por padrao; mantenha o diretorio gravavel.
USER appuser

EXPOSE 8000

# Liveness local: urllib faz parte da biblioteca padrao do Python.
HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

# Exec/JSON faz do Uvicorn o PID 1, permitindo que receba SIGTERM diretamente.
CMD ["uvicorn", "app.principal:api", "--host", "0.0.0.0", "--port", "8000"]