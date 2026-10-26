# syntax=docker/dockerfile:1

FROM debian:13-slim AS builder
ARG DEBIAN_FRONTEND=noninteractive
ARG MINQLX_COMMIT=fbdd915185337791d8e209dc4b686a1ee60d3721
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates build-essential python3-dev make \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN git clone https://github.com/MinoMino/minqlx.git \
    && cd minqlx \
    && git checkout "$MINQLX_COMMIT" \
    && make \
    && test -s bin/minqlx.x64.so \
    && test -s bin/minqlx.zip

FROM debian:13-slim
ARG DEBIAN_FRONTEND=noninteractive
LABEL org.opencontainers.image.source="https://github.com/obteo/quake-minqlx-debian13" \
      org.opencontainers.image.title="Quake Live minqlx Debian 13" \
      org.opencontainers.image.description="Pterodactyl v2 runtime: minqlx Python 3.13 and embedded Redis" \
      org.opencontainers.image.authors="Teo"
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl tar gzip procps \
    python3 libpython3.13 python3-redis python3-zmq python3-requests \
    redis-server redis-tools \
    libc6 libstdc++6 libgcc-s1 libcurl4t64 libatomic1 libnss3 \
    && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --home-dir /home/container --shell /bin/bash --uid 1000 container
COPY --from=builder /build/minqlx/bin/minqlx.x64.so /opt/minqlx/minqlx.x64.so
COPY --from=builder /build/minqlx/bin/minqlx.zip /opt/minqlx/minqlx.zip
COPY --from=builder /build/minqlx/bin/run_server_x64_minqlx.sh /opt/minqlx/run_server_x64_minqlx.sh
COPY --chmod=0755 entrypoint.sh /entrypoint.sh
RUN python3 -c 'import redis, zmq, requests; print("Python modules OK")' \
    && ldd /opt/minqlx/minqlx.x64.so | tee /tmp/minqlx-ldd \
    && ! grep -q 'not found' /tmp/minqlx-ldd \
    && redis-server --version
ENV USER=container HOME=/home/container
WORKDIR /home/container
USER container
ENTRYPOINT []
CMD ["/bin/bash", "/entrypoint.sh"]
