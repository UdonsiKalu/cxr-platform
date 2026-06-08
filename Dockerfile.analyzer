# CXR warm analyzer for Kubernetes (bootcamp SW.3+ / HPA stack)
# Build: scripts/02-build-analyzer-and-load.sh
# Context: claim_analysis_tools/ (CXR_ANALYZER_SRC)

FROM python:3.11-bookworm

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    curl gnupg apt-transport-https ca-certificates \
    unixodbc unixodbc-dev \
  && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
  && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
    > /etc/apt/sources.list.d/mssql-release.list \
  && apt-get update \
  && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql17 \
  && rm -rf /var/lib/apt/lists/*

COPY requirements-analyzer-docker.txt /tmp/requirements-analyzer-docker.txt
RUN pip install --no-cache-dir -r /tmp/requirements-analyzer-docker.txt

COPY . /app

# Ops-lab K8 only: v4_final kernel ignores env by default; patch in-image (source tree unchanged).
RUN python3 -c "\
from pathlib import Path; \
p = Path('/app/archetype_catalog_v3_1_master/cxr_kernel_v4_final.py'); \
t = p.read_text(); \
t = t.replace( \
  'SERVER = \"127.0.0.1,1433\"', \
  'SERVER = os.environ.get(\"CXR_SQL_SERVER\", \"127.0.0.1,1433\")' \
); \
t = t.replace( \
  'def __init__(self, qdrant_url: str = \"http://localhost:6333\"):', \
  'def __init__(self, qdrant_url: Optional[str] = None):\n        if qdrant_url is None:\n            qdrant_url = os.environ.get(\"CXR_QDRANT_URL\", \"http://localhost:6333\")' \
); \
p.write_text(t)"

ENV CXR_ANALYZER_HOST=0.0.0.0
ENV CXR_ANALYZER_PORT=8766
ENV CXR_TRACE_PROFILE=detailed
ENV OTEL_SERVICE_NAME=cxr-analyzer-service
ENV PYTHONUNBUFFERED=1

EXPOSE 8766

HEALTHCHECK --interval=30s --timeout=5s --start-period=300s --retries=3 \
  CMD curl -sf http://127.0.0.1:8766/health/ready || exit 1

CMD ["python3", "-m", "uvicorn", "analyzer_service_app:app", "--host", "0.0.0.0", "--port", "8766"]
