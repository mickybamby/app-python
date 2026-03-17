# ============================================================
# Stage 1 — builder
# Compiles wheels + runs test suite. Never shipped.
# ============================================================
FROM python:3.10-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        libffi-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --upgrade pip --no-cache-dir

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir pytest==8.3.5

COPY . .

# Failing tests abort the build — no broken image is ever produced
RUN chmod +x run-test.sh && ./run-test.sh


# ============================================================
# Stage 2 — deps
# Installs production-only packages into an isolated prefix.
# ============================================================
FROM python:3.10-slim AS deps

RUN pip install --upgrade pip --no-cache-dir

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ============================================================
# Stage 3 — runner  ← the only stage that reaches your registry
# No compiler. No test framework. No dev tooling.
# ============================================================
FROM python:3.10-slim AS runner

RUN apt-get update && apt-get install -y --no-install-recommends \
        dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1001 appgroup \
    && useradd  --system --uid 1001 --gid appgroup --no-create-home appuser

WORKDIR /app

COPY --from=deps    /install                  /usr/local
COPY --from=builder --chown=appuser:appgroup  /app/app.py  ./app.py

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONFAULTHANDLER=1 \
    PORT=8000

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT}/health')" \
    || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["python", "app.py"]