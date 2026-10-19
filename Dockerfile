
#Builder
FROM python:3.12-alpine AS builder

WORKDIR /app

# instala as dependências isoladas em uma pasta local
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# Imagem Final (Execução)
FROM python:3.12-alpine

# Cria usuário não-root (UID/GID fixo 10001 para segurança)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup -u 10001

WORKDIR /app

# copia os pacotes compilados no estágio de build
COPY --from=builder /install /usr/local

# copia o código da aplicação e arquivos estáticos
COPY app/ ./app/
COPY static/ ./static/

# configura as permissões para o usuário não-root
RUN chown -R appuser:appgroup /app

# transfere a execução para o usuário não-root
USER appuser

# expõe a porta da aplicação (padrão 8000)
EXPOSE 8000

# requisito 5: HEALTHCHECK consultando /health via python sem depender de curl/wget
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; exit(0 if urllib.request.urlopen('http://localhost:8000/health').getcode() == 200 else 1)"

# requisito 4: CMD na forma exec para receber SIGTERM corretamente e encerrar em < 2s (PID 1)
CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
