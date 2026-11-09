# Estagio 1: construcao das dependencias
FROM python:3.12-alpine AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# Estagio 2: imagem final
FROM python:3.12-alpine

WORKDIR /app

COPY --from=builder /install /usr/local

COPY app/ ./app/
COPY static/ ./static/

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
