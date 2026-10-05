FROM python:3.12-alpine AS builder

RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --no-compile \
        fastapi==0.141.1 uvicorn==0.53.0 \
    && rm -rf /opt/venv/lib/python3.12/site-packages/pip \
        /opt/venv/lib/python3.12/site-packages/pip-*.dist-info \
        /opt/venv/lib/python3.12/site-packages/setuptools*

FROM python:3.12-alpine

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SQLITE_PATH=/app/data/loja.db

WORKDIR /app

RUN addgroup -S loja \
    && adduser -S -G loja loja \
    && mkdir -p /app/data \
    && chown -R loja:loja /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=loja:loja app ./app
COPY --chown=loja:loja static ./static

USER loja

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]