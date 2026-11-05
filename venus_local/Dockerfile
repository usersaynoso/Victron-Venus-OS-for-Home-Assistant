ARG BUILD_FROM=ubuntu:24.04

FROM ${BUILD_FROM} AS extract

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

# Venus OS v3.85 dropped dbus-mqtt in favour of the FlashMQ D-Bus plugin. The
# launcher still bridges D-Bus to MQTT with dbus-mqtt, so restore Victron's
# last release (v1.36) and the velib_python revision it pins when it is absent.
ARG DBUS_MQTT_REF=225eadf59dddf1c505f997764c0c7535f6dae202
ARG VELIB_PYTHON_REF=8e8e19966ed51e182d2e7458d834ab0b32ad72d7

RUN if [ ! -e /venus-rootfs/opt/victronenergy/dbus-mqtt/dbus_mqtt.py ]; then \
      dbus_mqtt_dir=/venus-rootfs/opt/victronenergy/dbus-mqtt \
      && mkdir -p "${dbus_mqtt_dir}/ext/velib_python" \
      && curl -fsSL "https://codeload.github.com/victronenergy/dbus-mqtt/tar.gz/${DBUS_MQTT_REF}" \
         | tar -xz --strip-components=1 -C "${dbus_mqtt_dir}" \
      && curl -fsSL "https://codeload.github.com/victronenergy/velib_python/tar.gz/${VELIB_PYTHON_REF}" \
         | tar -xz --strip-components=1 -C "${dbus_mqtt_dir}/ext/velib_python" \
      && test -x "${dbus_mqtt_dir}/dbus_mqtt.py" \
      && test -f "${dbus_mqtt_dir}/mqtt_gobject_bridge.py" \
      && test -f "${dbus_mqtt_dir}/ext/velib_python/ve_utils.py"; \
    fi

FROM scratch

ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket

COPY --from=extract /venus-rootfs/ /
COPY run.sh /run.sh

EXPOSE 80 502 1883

CMD ["/run.sh"]
