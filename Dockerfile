FROM python:3.12-alpine AS builder

WORKDIR /build
RUN python -m venv /opt/venv
COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt \
    && /opt/venv/bin/pip uninstall -y pip setuptools

FROM python:3.12-alpine

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY app /app/app
COPY static /app/static
RUN addgroup -S app && adduser -S -G app app \
    && chown -R app:app /app

ENV PATH="/opt/venv/bin:$PATH" \
    SQLITE_PATH=/app/loja.db \
    PYTHONDONTWRITEBYTECODE=1
EXPOSE 8000
HEALTHCHECK --interval=5s --timeout=2s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=1)"
USER app
CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]