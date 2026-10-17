FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

COPY install-deps.sh /usr/local/bin/dylanos-install-deps
RUN chmod 0755 /usr/local/bin/dylanos-install-deps \
    && /usr/local/bin/dylanos-install-deps \
    && rm /usr/local/bin/dylanos-install-deps

COPY . /workspace

ENTRYPOINT ["/bin/bash", "/workspace/scripts/build.sh"]
