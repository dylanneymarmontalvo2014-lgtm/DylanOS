# Entorno de construcción para DylanOS en Linux amd64.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /tmp/dylanos

COPY init.sh ./init.sh
COPY scripts/build-host.sh ./scripts/build-host.sh
COPY scripts/docker-compose.sh ./scripts/docker-compose.sh
COPY apps/workspace/requirements-dev.txt ./apps/workspace/requirements-dev.txt
RUN DYLANOS_VENV=/opt/dylanos-venv bash init.sh --yes \
    && printf 'root ALL=(ALL:ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/00-root-nopasswd \
    && chmod 0440 /etc/sudoers.d/00-root-nopasswd \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHON=/opt/dylanos-venv/bin/python
WORKDIR /workspace
