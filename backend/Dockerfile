FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# System deps for httpx, google-auth, etc. Most pulls are pure Python wheels;
# build-essential is here only as a safety net for older arches.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
COPY app ./app

RUN pip install --upgrade pip \
    && pip install -e .

# /data is the Fly volume mount point; if no volume is attached the path
# falls back to a local directory inside the container.
ENV NOETICA_DB_PATH=/data/noetica.db
RUN mkdir -p /data

EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
