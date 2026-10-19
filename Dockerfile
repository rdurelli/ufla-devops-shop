FROM python:3.12-alpine AS builder

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

RUN python -m venv "${VIRTUAL_ENV}"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


FROM python:3.12-alpine AS runtime

ENV VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN addgroup -S app && \
    adduser -S -G app -h /app app && \
    mkdir -p /app && \
    chown app:app /app

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=app:app app ./app
COPY --chown=app:app static ./static

USER app

EXPOSE 8000

HEALTHCHECK --interval=5s --timeout=2s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=1)"]

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
