FROM postgres:15-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-venv \
    && python3 -m venv /opt/patroni-venv \
    && /opt/patroni-venv/bin/pip install --no-cache-dir \
        "patroni[zookeeper]==4.1.5" \
        "psycopg2-binary==2.9.10" \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/patroni-venv/bin:${PATH}"

COPY --chown=postgres:postgres postgres0.yml postgres1.yml /

USER postgres
