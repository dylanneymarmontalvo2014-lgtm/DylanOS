# Entorno de construcción para DylanOS en Linux amd64.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && arch="$(dpkg --print-architecture)" \
    && echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       debootstrap desktop-file-utils dosfstools gnupg grub-common \
       grub-efi-amd64-bin grub-pc-bin libdbus-1-3 libegl1 libfontconfig1 \
       libfreetype6 libglib2.0-0t64 libopengl0 libx11-6 libx11-xcb1 \
       libxcb-cursor0 libxcb-icccm4 libxcb-keysyms1 libxcb-randr0 \
       libxcb-render-util0 libxcb-shape0 libxcb-xfixes0 libxcb-xkb1 \
       libxkbcommon0 libxkbcommon-x11-0 make mtools nodejs python3 \
       python3-pip python3-venv shellcheck sudo \
       squashfs-tools util-linux xorriso \
    && printf 'root ALL=(ALL:ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/00-root-nopasswd \
    && chmod 0440 /etc/sudoers.d/00-root-nopasswd \
    && rm -rf /var/lib/apt/lists/*

COPY apps/workspace/requirements-dev.txt /tmp/requirements-dev.txt
RUN python3 -m venv /opt/dylanos-venv \
    && /opt/dylanos-venv/bin/pip install --no-cache-dir -r /tmp/requirements-dev.txt \
    && rm /tmp/requirements-dev.txt

ENV PYTHON=/opt/dylanos-venv/bin/python
WORKDIR /workspace
