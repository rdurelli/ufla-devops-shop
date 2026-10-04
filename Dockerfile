# Estagio 1: instala as deps numa venv. O pip e o cache ficam aqui e nao vao pro final.
FROM python:3.12-alpine AS builder
WORKDIR /build
RUN python -m venv /opt/venv
COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# Estagio 2: so o que precisa para rodar. Alpine para caber em < 150 MB.
FROM python:3.12-alpine
RUN adduser -D -u 1000 loja
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY app/ app/
COPY static/ static/
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    SQLITE_PATH=/tmp/loja.db
USER loja
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=8s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
