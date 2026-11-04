# syntax=docker/dockerfile:1
#
# tdt-local en Docker — imagen no oficial de https://github.com/cibernicola/tdt-local
# La fuente se descarga del release de GitHub de la versión fijada en TDT_VERSION y se comprueba con su SHA-256.
# Para subir de versión: cambia TDT_VERSION y TDT_SHA256 (ver README).

FROM python:3.12-slim

ARG TDT_VERSION=1.3.0
ARG TDT_SHA256=dc3f2bc7eb25d35919b572e7b2072cbf8082b062c3d80d5a4f1828f36bdf6862
ARG WITH_FFMPEG=1

LABEL org.opencontainers.image.title="tdt-local" \
      org.opencontainers.image.description="Visor local de la TDT española y la radio (TDTChannels), en Docker" \
      org.opencontainers.image.version="${TDT_VERSION}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/cibernicola/tdt-local" \
      org.opencontainers.image.url="https://github.com/pcaro/tdt-local-docker" \
      org.opencontainers.image.documentation="https://github.com/pcaro/tdt-local-docker#readme"

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TDT_DATA_DIR=/data \
    TDT_MODELS_DIR=/data/models

# ffmpeg solo hace falta para los subtítulos (whisper) y las marcas de publicidad SCTE-35; pesa ~450 MB.
RUN set -eux; \
    if [ "$WITH_FFMPEG" = "1" ]; then \
        apt-get update; \
        apt-get install -y --no-install-recommends ffmpeg; \
        rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /src
ADD https://github.com/cibernicola/tdt-local/archive/refs/tags/v${TDT_VERSION}.tar.gz /tmp/tdt-local.tar.gz
RUN set -eux; \
    echo "${TDT_SHA256}  /tmp/tdt-local.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/tdt-local.tar.gz --strip-components=1; \
    rm /tmp/tdt-local.tar.gz; \
    pip install --no-cache-dir .; \
    mkdir -p /usr/share/doc/tdt-local; \
    cp LICENSE NOTICE /usr/share/doc/tdt-local/; \
    rm -rf /src

WORKDIR /data
VOLUME ["/data"]
EXPOSE 8788

HEALTHCHECK --interval=60s --timeout=10s --start-period=40s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8788/api/version', timeout=8)"]

# --lan = escuchar en 0.0.0.0. Sin autenticación: no lo publiques fuera de tu red local.
CMD ["tdt-local", "--lan", "--port", "8788", "--data-dir", "/data"]
