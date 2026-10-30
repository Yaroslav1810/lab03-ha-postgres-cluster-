FROM postgres:15-bookworm AS patroni-base

# Diagnostic utilities and an isolated Python environment for Patroni.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl netcat-openbsd iputils-ping python3-venv \
    && rm -rf /var/lib/apt/lists/*

ARG PATRONI_VERSION=4.1.5
ARG PSYCOPG2_VERSION=2.9.10
RUN python3 -m venv /opt/patroni-venv \
    && /opt/patroni-venv/bin/pip install --no-cache-dir \
        "patroni[zookeeper]==${PATRONI_VERSION}" \
        "psycopg2-binary==${PSYCOPG2_VERSION}"

ENV PATH="/opt/patroni-venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1

USER postgres
# Override the postgres image's default CMD: Patroni owns initialization.
# Compose will replace this with: patroni /postgres0.yml (or /postgres1.yml).
CMD ["patroni", "--help"]

# Final image requires the real configurations delivered in stage 3.
# Until then, build with --target patroni-base to verify stage 2 independently.
FROM patroni-base AS cluster
COPY --chown=postgres:postgres --chmod=0600 postgres0.yml /postgres0.yml
COPY --chown=postgres:postgres --chmod=0600 postgres1.yml /postgres1.yml
