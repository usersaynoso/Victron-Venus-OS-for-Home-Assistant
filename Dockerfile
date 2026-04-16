ARG BUILD_FROM=ubuntu:24.04

FROM --platform=$BUILDPLATFORM ${BUILD_FROM} AS extract

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG VENUS_IMAGE_DIR=raspberrypi4
ARG VENUS_SWU=venus-swu-3-large-raspberrypi4.swu

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      cpio \
      curl \
      e2fsprogs \
      gzip \
      xz-utils \
      zstd \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/venus

RUN curl -fsSLO "https://updates.victronenergy.com/feeds/venus/release/images/${VENUS_IMAGE_DIR}/${VENUS_SWU}" \
 && cpio -idmu < "${VENUS_SWU}" \
 && rootfs_gz="$(find . -maxdepth 1 -type f -name 'venus-image-*.ext4.gz' -print -quit)" \
 && test -n "${rootfs_gz}" \
 && gzip -dc "${rootfs_gz}" > venus-rootfs.ext4 \
 && mkdir -p /venus-rootfs \
 && debugfs -R "rdump / /venus-rootfs" venus-rootfs.ext4 \
 && mkdir -p /venus-rootfs/var \
 && rm -rf /venus-rootfs/service /venus-rootfs/tmp /venus-rootfs/var/log /venus-rootfs/var/run \
 && ln -sfn /run/service /venus-rootfs/service \
 && ln -sfn /run/tmp /venus-rootfs/tmp \
 && ln -sfn /run/log /venus-rootfs/var/log \
 && ln -sfn /run /venus-rootfs/var/run \
 && rm -f "${VENUS_SWU}" "${rootfs_gz}" venus-rootfs.ext4

FROM scratch

ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket

COPY --from=extract /venus-rootfs/ /
COPY --chmod=0755 run.sh /run.sh

EXPOSE 80 502 1883

CMD ["/run.sh"]
