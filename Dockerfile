FROM python:3.12-alpine AS builder

WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && find /opt/venv -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

FROM python:3.12-alpine

WORKDIR /app

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN adduser -D -u 1000 ufla-shop-user && chown -R ufla-shop-user:ufla-shop-user /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=ufla-shop-user:ufla-shop-user app/ ./app/
COPY --chown=ufla-shop-user:ufla-shop-user static/ ./static/

USER ufla-shop-user

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
