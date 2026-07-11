FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends clang ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server/deploy/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY engine ./engine
COPY research ./research
COPY clients/flutter_app/assets/policies ./clients/flutter_app/assets/policies
COPY server ./server

RUN python -c 'from research.kolkhoz_research.c_engine import CEngine; CEngine()'

RUN groupadd --system kolkhoz \
    && useradd --system --gid kolkhoz --home-dir /app kolkhoz \
    && chown -R kolkhoz:kolkhoz /app

USER kolkhoz

EXPOSE 8787
CMD ["python", "-m", "server.kolkhoz_server.production"]
