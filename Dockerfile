FROM python:3.12-alpine AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --user --no-cache-dir -r requirements.txt


FROM python:3.12-alpine

WORKDIR /app

RUN adduser -D appuser

COPY --from=builder /root/.local /home/appuser/.local

COPY app ./app
COPY static ./static

RUN chown -R appuser:appuser /app /home/appuser/.local

ENV PATH="/home/appuser/.local/bin:${PATH}"

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]