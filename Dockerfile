FROM python:3.12-alpine AS build

RUN python -m venv /opt/venv
COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt \
 && /opt/venv/bin/pip uninstall -y pip \
 && find /opt/venv -name __pycache__ -type d -prune -exec rm -rf {} +


FROM python:3.12-alpine

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SQLITE_PATH=/dados/loja.db

RUN addgroup -S -g 10001 loja \
 && adduser -S -D -H -u 10001 -G loja loja \
 && install -d -o loja -g loja /dados

WORKDIR /app
COPY --from=build /opt/venv /opt/venv
COPY app/ app/
COPY static/ static/

USER loja
EXPOSE 8000

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
