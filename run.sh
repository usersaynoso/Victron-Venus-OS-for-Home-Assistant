#!/bin/sh
set -eu

SERIAL_DEVICE="${SERIAL_DEVICE:-}"
DBUS_SOCKET="${DBUS_SOCKET:-/run/dbus/system_bus_socket}"
SVDIR="${SVDIR:-/run/service}"
LOCALSETTINGS_PID=""
SERIAL_SCAN_PID=""
SVSCANBOOT_PID=""
PHP_FPM_PID=""
NGINX_PID=""
FLASHMQ_PID=""
DBUS_MQTT_PID=""
MODBUSTCP_PID=""
UNIQUE_ID=""
SERIAL_TTY=""
SERIAL_STARTER_DEVICE_DIR="/run/serial-starter-devices"
MK2_DBUS_PID=""
SYSTEMCALC_PID=""
PLATFORM_PID=""
MQTT_BOOTSTRAP_PID=""

log() {
  echo "[venus_local] $*"
}

log "Launcher build 2026-04-16.9"

cleanup() {
  for pid in "$LOCALSETTINGS_PID" "$SERIAL_SCAN_PID" "$PHP_FPM_PID" "$NGINX_PID" "$FLASHMQ_PID" "$DBUS_MQTT_PID" "$MODBUSTCP_PID" "$MK2_DBUS_PID" "$SYSTEMCALC_PID" "$PLATFORM_PID" "$MQTT_BOOTSTRAP_PID" "$SVSCANBOOT_PID"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
}

trap cleanup EXIT INT TERM

require_path() {
  if [ ! -e "$1" ]; then
    log "Required path is missing: $1"
    exit 1
  fi
}

load_serial_device_from_options() {
  if [ -n "$SERIAL_DEVICE" ]; then
    return 0
  fi

  if [ ! -f /data/options.json ]; then
    return 0
  fi

  SERIAL_DEVICE="$(python3 - <<'PY'
import json
from pathlib import Path

options_path = Path("/data/options.json")
try:
    data = json.loads(options_path.read_text())
except Exception:
    print("", end="")
else:
    value = data.get("serial_device") or ""
    print(value, end="")
PY
)"
}

autodetect_serial_device() {
  if [ -n "$SERIAL_DEVICE" ]; then
    return 0
  fi

  for candidate in /dev/serial/by-id/*VictronEnergy*MK3* /dev/serial/by-id/*; do
    if [ -e "$candidate" ]; then
      SERIAL_DEVICE="$candidate"
      log "Auto-detected serial device at $SERIAL_DEVICE"
      return 0
    fi
  done

  return 1
}

resolve_serial_tty() {
  SERIAL_TTY="$(python3 - "$SERIAL_DEVICE" <<'PY'
import os
import sys

resolved = os.path.realpath(sys.argv[1])
print(os.path.basename(resolved), end="")
PY
)"

  if [ -z "$SERIAL_TTY" ] || [ ! -c "/dev/$SERIAL_TTY" ]; then
    log "Unable to resolve a kernel tty from $SERIAL_DEVICE"
    exit 1
  fi
}

ensure_serial_starter_device() {
  mkdir -p "$SERIAL_STARTER_DEVICE_DIR"
  ln -sfn "/dev/$SERIAL_TTY" "$SERIAL_STARTER_DEVICE_DIR/$SERIAL_TTY"
  log "Linked $SERIAL_STARTER_DEVICE_DIR/$SERIAL_TTY to /dev/$SERIAL_TTY"
}

enable_service() {
  name="$1"
  src="$2"

  if [ ! -d "$src" ]; then
    log "Skipping missing service directory: $src"
    return
  fi

  ln -sfn "$src" "$SVDIR/$name"
}

enable_template_service() {
  name="$1"
  src="$2"
  dst="/var/volatile/services/$name"

  if [ ! -d "$src" ]; then
    log "Skipping missing service template: $src"
    return
  fi

  rm -rf "$dst"
  mkdir -p /var/volatile/services
  cp -a "$src" "$dst"
  ln -sfn "$dst" "$SVDIR/$name"
}

dbus_setting_ready() {
  dbus_name_ready com.victronenergy.settings
}

dbus_name_ready() {
  name="$1"
  dbus-send --system --print-reply \
    --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus \
    org.freedesktop.DBus.NameHasOwner \
    string:"$name" 2>/dev/null | grep -q 'boolean true'
}

wait_for_settings() {
  timeout="${1:-60}"
  elapsed=0

  while [ "$elapsed" -lt "$timeout" ]; do
    if dbus_setting_ready; then
      return 0
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

wait_for_dbus_name() {
  name="$1"
  label="$2"
  timeout="${3:-60}"
  elapsed=0

  while [ "$elapsed" -lt "$timeout" ]; do
    if dbus_name_ready "$name"; then
      log "$label is ready on D-Bus"
      return 0
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  log "$label did not appear on D-Bus within ${timeout}s"
  return 1
}

port_open() {
  python3 - "$1" <<'PY'
import socket
import sys

port = int(sys.argv[1])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(1.0)
try:
    sock.connect(("127.0.0.1", port))
except OSError:
    raise SystemExit(1)
finally:
    sock.close()
PY
}

wait_for_port() {
  port="$1"
  label="$2"
  timeout="${3:-60}"
  elapsed=0

  while [ "$elapsed" -lt "$timeout" ]; do
    if port_open "$port"; then
      log "$label is listening on port $port"
      return 0
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  log "$label did not open port $port within ${timeout}s"
  return 1
}

wait_for_process() {
  pattern="$1"
  label="$2"
  timeout="${3:-60}"
  elapsed=0

  while [ "$elapsed" -lt "$timeout" ]; do
    if ps | grep -F "$pattern" | grep -v grep >/dev/null 2>&1; then
      log "$label is running"
      return 0
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  log "$label did not start within ${timeout}s"
  return 1
}

restart_serial_starter() {
  if ! command -v svc >/dev/null 2>&1; then
    log "svc is unavailable; skipping serial-starter restart."
    return 1
  fi

  if [ ! -L "$SVDIR/serial-starter" ]; then
    log "serial-starter service link is missing at $SVDIR/serial-starter"
    return 1
  fi

  log "Restarting serial-starter after settings are ready"
  svc -t "$SVDIR/serial-starter"
}

trigger_serial_scan() {
  require_path /opt/victronenergy/serial-starter/serial-starter.sh
  log "Triggering a manual serial-starter scan"
  /opt/victronenergy/serial-starter/serial-starter.sh &
  SERIAL_SCAN_PID=$!
}

ensure_nginx_prereqs() {
  mkdir -p /data/etc/ssl /var/volatile/log/nginx

  if [ -s /data/etc/ssl/venus.local.crt ] && [ -s /data/etc/ssl/venus.local.key ]; then
    return 0
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    log "openssl is unavailable; cannot generate the nginx certificate."
    return 1
  fi

  log "Generating a self-signed nginx certificate"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /data/etc/ssl/venus.local.key \
    -out /data/etc/ssl/venus.local.crt \
    -days 3650 \
    -subj "/CN=venus.local" >/dev/null 2>&1
}

ensure_flashmq_config() {
  require_path /usr/bin/flashmq

  mkdir -p /etc/flashmq /run/flashmq

  cat >/etc/flashmq/flashmq.conf <<'EOF'
thread_count 1
max_packet_size 16777216
client_max_write_buffer_size 8388608
include_dir /run/flashmq
allow_anonymous true
zero_byte_username_is_anonymous true
log_level notice
listen {
    protocol mqtt
    port 1883
}
listen {
    protocol mqtt
    port 8883
    fullchain /data/keys/mosquitto.crt
    privkey /data/keys/mosquitto.key
}
listen {
    protocol websockets
    port 9001
}
EOF
}

start_nginx_fallback() {
  if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
    return 0
  fi

  if [ ! -x /usr/sbin/nginx ]; then
    log "nginx binary is not available for direct startup."
    return 1
  fi

  log "Testing nginx configuration"
  if ! /usr/sbin/nginx -t 2>&1 | sed 's/^/[venus_local] /'; then
    log "nginx configuration test failed."
    return 1
  fi

  log "Starting nginx directly"
  /usr/sbin/nginx &
  NGINX_PID=$!
}

start_flashmq_direct() {
  require_path /usr/sbin/start-flashmq

  if [ -n "$FLASHMQ_PID" ] && kill -0 "$FLASHMQ_PID" 2>/dev/null; then
    return 0
  fi

  log "Starting FlashMQ directly"
  /usr/sbin/start-flashmq &
  FLASHMQ_PID=$!
}

start_dbus_mqtt_direct() {
  require_path /opt/victronenergy/dbus-mqtt/dbus_mqtt.py

  if [ -n "$DBUS_MQTT_PID" ] && kill -0 "$DBUS_MQTT_PID" 2>/dev/null; then
    return 0
  fi

  log "Starting dbus-mqtt directly"
  /opt/victronenergy/dbus-mqtt/dbus_mqtt.py -k 31536000 &
  DBUS_MQTT_PID=$!
}

start_modbustcp_direct() {
  require_path /opt/victronenergy/dbus-modbustcp/dbus-modbustcp

  if [ -n "$MODBUSTCP_PID" ] && kill -0 "$MODBUSTCP_PID" 2>/dev/null; then
    return 0
  fi

  log "Starting dbus-modbustcp directly"
  /opt/victronenergy/dbus-modbustcp/dbus-modbustcp &
  MODBUSTCP_PID=$!
}

start_mk2_dbus_direct() {
  settings_file="/data/var/lib/mk2-dbus/mkxport-$SERIAL_TTY.settings"

  require_path /opt/victronenergy/mk2-dbus/mk2-dbus

  if [ -n "$MK2_DBUS_PID" ] && kill -0 "$MK2_DBUS_PID" 2>/dev/null; then
    return 0
  fi

  log "Starting mk2-dbus directly on /dev/$SERIAL_TTY"
  /opt/victronenergy/mk2-dbus/mk2-dbus \
    --log-before 25 \
    --log-after 25 \
    --banner \
    -w \
    -s "/dev/$SERIAL_TTY" \
    -t mk3 \
    --settings "$settings_file" &
  MK2_DBUS_PID=$!
}

start_systemcalc_direct() {
  require_path /opt/victronenergy/dbus-systemcalc-py/dbus_systemcalc.py

  if [ -n "$SYSTEMCALC_PID" ] && kill -0 "$SYSTEMCALC_PID" 2>/dev/null; then
    return 0
  fi

  log "Starting dbus-systemcalc directly"
  /opt/victronenergy/dbus-systemcalc-py/dbus_systemcalc.py &
  SYSTEMCALC_PID=$!
}

start_platform_direct() {
  if [ ! -x /opt/victronenergy/venus-platform/venus-platform ]; then
    log "venus-platform is unavailable; skipping platform service startup."
    return 0
  fi

  if [ -n "$PLATFORM_PID" ] && kill -0 "$PLATFORM_PID" 2>/dev/null; then
    return 0
  fi

  log "Starting venus-platform directly"
  /opt/victronenergy/venus-platform/venus-platform &
  PLATFORM_PID=$!
}

prime_mqtt_snapshot() {
  log "Priming the local MQTT snapshot"
  python3 - "$UNIQUE_ID" <<'PY'
import json
import sys
import time

import paho.mqtt.client as mqtt

system_id = sys.argv[1]
serial_topic = f"N/{system_id}/system/0/Serial"
received_serial = False


def on_connect(client, userdata, flags, rc, properties=None):
    client.subscribe(f"N/{system_id}/#")
    client.publish(f"R/{system_id}/keepalive", b"")
    client.publish(f"R/{system_id}/system/0/Serial", b"")
    for path, value in (
        ("settings/0/Settings/System/Units/Temperature", 0),
        ("settings/0/Settings/System/Units/Altitude", 0),
        ("settings/0/Settings/System/VolumeUnit", 0),
        ("settings/0/Settings/Gui/ElectricalPowerIndicator", 0),
    ):
        client.publish(f"W/{system_id}/{path}", json.dumps({"value": value}))


def on_message(client, userdata, msg):
    global received_serial
    if msg.topic == serial_topic:
        received_serial = True


client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id="venus-local-primer")
client.on_connect = on_connect
client.on_message = on_message
client.connect("127.0.0.1", 1883, 10)
client.loop_start()
deadline = time.time() + 10
while time.time() < deadline and not received_serial:
    time.sleep(0.2)
client.loop_stop()
client.disconnect()

if not received_serial:
    raise SystemExit(1)
PY
  log "The local MQTT snapshot is primed"
}

start_mqtt_bootstrap_republisher() {
  if [ -n "$MQTT_BOOTSTRAP_PID" ] && kill -0 "$MQTT_BOOTSTRAP_PID" 2>/dev/null; then
    return 0
  fi

  log "Republishing retained MQTT bootstrap topics during startup"
  python3 - "$UNIQUE_ID" <<'PY' &
import json
import sys
import time

import paho.mqtt.client as mqtt

system_id = sys.argv[1]
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="venus-local-bootstrap", clean_session=True)
client.connect("127.0.0.1", 1883, 10)
client.loop_start()
for _ in range(30):
    client.publish(f"N/{system_id}/system/0/Serial", json.dumps({"value": system_id}), retain=True).wait_for_publish()
    client.publish(f"N/{system_id}/keepalive", json.dumps({"value": 1}), retain=True).wait_for_publish()
    time.sleep(2)
client.loop_stop()
client.disconnect()
PY
  MQTT_BOOTSTRAP_PID=$!
}

ensure_unique_id() {
  local_id_file="/data/conf/venus-local-unique-id"

  UNIQUE_ID="$(python3 - "$local_id_file" "$SERIAL_DEVICE" <<'PY'
import hashlib
import os
import re
import sys
from pathlib import Path

id_path = Path(sys.argv[1])
serial_device = sys.argv[2]

for candidate in Path("/sys/class/net").glob("*/address"):
    iface = candidate.parent.name
    if iface == "lo":
        continue
    try:
        mac = re.sub(r"[^0-9A-Fa-f]", "", candidate.read_text()).lower()
    except OSError:
        continue
    if len(mac) == 12:
        print(mac, end="")
        raise SystemExit(0)

if id_path.is_file():
    persisted = re.sub(r"[^0-9A-Fa-f]", "", id_path.read_text()).lower()
    if len(persisted) == 12:
        print(persisted, end="")
        raise SystemExit(0)

seed = serial_device or ""
generated = hashlib.sha256(seed.encode("utf-8")).hexdigest()[:12]
id_path.write_text(generated + "\n")
print(generated, end="")
PY
)"

  cat >/sbin/get-unique-id <<EOF
#!/bin/sh
echo "$UNIQUE_ID"
EOF
  chmod 0755 /sbin/get-unique-id
  log "Using unique VRM identifier $UNIQUE_ID"
}

ensure_dbus_mqtt_compat() {
  require_path /opt/victronenergy/dbus-mqtt/mqtt_gobject_bridge.py
  require_path /opt/victronenergy/dbus-mqtt/dbus_mqtt.py

  python3 - <<'PY'
from pathlib import Path

bridge_path = Path("/opt/victronenergy/dbus-mqtt/mqtt_gobject_bridge.py")
source = bridge_path.read_text()
old = "self._client = paho.mqtt.client.Client(client_id)"
new = "self._client = paho.mqtt.client.Client(paho.mqtt.client.CallbackAPIVersion.VERSION1, client_id)"
source = source.replace("self._client.loop_write(10)", "self._client.loop_write()")

if old in source and "CallbackAPIVersion.VERSION1" not in source:
    source = source.replace(old, new)

bridge_path.write_text(source)

dbus_mqtt_path = Path("/opt/victronenergy/dbus-mqtt/dbus_mqtt.py")
dbus_mqtt_source = dbus_mqtt_path.read_text()
start = dbus_mqtt_source.find("\tdef _handle_keepalive(self, payload):\n")
end = dbus_mqtt_source.find("\n\tdef _handle_write", start)
if start != -1 and end != -1:
    replacement = (
        "\tdef _handle_keepalive(self, payload):\n"
        "\t\tif payload:\n"
        "\t\t\trequest = json.loads(payload)\n"
        "\t\t\tif isinstance(request, dict):\n"
        "\t\t\t\ttopics = request.get('topics') or []\n"
        "\t\t\t\tif not topics:\n"
        "\t\t\t\t\tif self._subscriptions.subscribe_all(self._keep_alive_interval) is not None:\n"
        "\t\t\t\t\t\tself._publish_all()\n"
        "\t\t\t\t\treturn\n"
        "\t\t\telse:\n"
        "\t\t\t\ttopics = request\n"
        "\t\t\tfor topic in topics:\n"
        "\t\t\t\tob = self._subscriptions.subscribe(topic, self._keep_alive_interval)\n"
        "\t\t\t\tif ob is not None:\n"
        "\t\t\t\t\tfor k, v in self._values.items():\n"
        "\t\t\t\t\t\tpt = PublishedTopic(k)\n"
        "\t\t\t\t\t\tif pt not in self._published and ob.match(pt.shorttopic):\n"
        "\t\t\t\t\t\t\tself._published.add(pt)\n"
        "\t\t\t\t\t\t\tself._publish(k, v)\n"
        "\t\telse:\n"
        "\t\t\tif self._subscriptions.subscribe_all(self._keep_alive_interval) is not None:\n"
        "\t\t\t\tself._publish_all()\n"
    )
    dbus_mqtt_source = dbus_mqtt_source[:start] + replacement + dbus_mqtt_source[end:]

dbus_mqtt_path.write_text(dbus_mqtt_source)
PY
}

ensure_serial_starter_compat() {
  require_path /opt/victronenergy/serial-starter/serial-starter.sh

  python3 - "$SERIAL_STARTER_DEVICE_DIR" <<'PY'
from pathlib import Path
import sys

path = Path("/opt/victronenergy/serial-starter/serial-starter.sh")
device_dir = sys.argv[1]
source = path.read_text()
patched = source.replace("/dev/serial-starter", device_dir)

if patched != source:
    path.write_text(patched)
PY
}

mkdir -p \
  /data \
  /data/conf \
  /data/conf/serial-starter.d \
  /data/keys \
  /data/var/lib/mk2-dbus \
  /data/var/lib/serial-starter \
  /run/dbus \
  /run/flashmq \
  /run/log \
  /run/nginx \
  /run/serial-starter \
  /run/service \
  /run/tmp \
  /var/volatile/log \
  /var/volatile/services

echo "container" >/tmp/last_boot_type

load_serial_device_from_options
autodetect_serial_device || true

if [ -z "$SERIAL_DEVICE" ]; then
  log "No serial device configured. Set the add-on serial_device option to a stable path under /dev/serial/by-id/."
  ls -l /dev/serial/by-id 2>/dev/null || true
  exit 1
fi

if [ ! -c "$SERIAL_DEVICE" ]; then
  log "Expected MK3-USB adapter at $SERIAL_DEVICE, but the device node is missing."
  ls -l /dev/serial/by-id 2>/dev/null || true
  exit 1
fi

resolve_serial_tty

cat >/data/conf/serial-starter.d/venus-local.conf <<'EOF'
alias default mkx
EOF

log "MK3-USB detected at $SERIAL_DEVICE; the Ignore AC Input registers are ready to vibe."

ensure_serial_starter_device
ensure_unique_id
ensure_serial_starter_compat
ensure_dbus_mqtt_compat
ensure_nginx_prereqs || true
ensure_flashmq_config

if [ ! -S "$DBUS_SOCKET" ]; then
  log "Starting system D-Bus daemon"
  dbus-daemon --system --fork --nopidfile
fi

require_path /opt/victronenergy/localsettings/localsettings.py
log "Starting localsettings"
/opt/victronenergy/localsettings/localsettings.py --path=/data/conf &
LOCALSETTINGS_PID=$!

enable_service nginx /opt/victronenergy/service/nginx

if [ -x /usr/sbin/php-fpm ]; then
  log "Starting php-fpm"
  /usr/sbin/php-fpm -F &
  PHP_FPM_PID=$!
fi

if command -v svscan >/dev/null 2>&1; then
  log "Starting daemontools supervisor"
  svscan "$SVDIR" &
  SVSCANBOOT_PID=$!
elif command -v svscanboot >/dev/null 2>&1; then
  log "Starting daemontools supervisor"
  SVDIR="$SVDIR" svscanboot &
  SVSCANBOOT_PID=$!
else
  log "svscanboot is not available in the Venus rootfs."
  exit 1
fi

if ! wait_for_settings 90; then
  log "Victron settings service did not come up on D-Bus."
  exit 1
fi

log "Victron settings service is ready on D-Bus"

start_mk2_dbus_direct
start_platform_direct
start_flashmq_direct
start_dbus_mqtt_direct
start_modbustcp_direct
start_systemcalc_direct

if ! wait_for_port 80 "Nginx Web UI" 20; then
  start_nginx_fallback || true
  wait_for_port 80 "Nginx Web UI" 70
fi

if ! wait_for_process "/opt/victronenergy/mk2-dbus/" "mk2-dbus" 90; then
  log "mk2-dbus did not start; leaving the web UI up for inspection."
fi

if ! wait_for_port 1883 "FlashMQ" 30; then
  log "FlashMQ is not ready yet; continuing so the web UI remains available."
fi

if ! wait_for_port 9001 "FlashMQ WebSockets" 30; then
  log "FlashMQ WebSockets are not ready yet; the GUI may still fail to connect."
fi

if ! wait_for_port 502 "Modbus TCP" 30; then
  log "Modbus TCP is not ready yet; continuing so the web UI remains available."
fi

wait_for_process "/opt/victronenergy/dbus-mqtt/" "dbus-mqtt" 30 || true
wait_for_dbus_name com.victronenergy.platform "venus-platform" 30 || true
wait_for_dbus_name com.victronenergy.system "dbus-systemcalc" 30 || true
wait_for_dbus_name "com.victronenergy.vebus.$SERIAL_TTY" "VE.Bus service" 60 || true

start_mqtt_bootstrap_republisher

snapshot_primed=0
for _ in 1 2 3 4 5 6; do
  if prime_mqtt_snapshot; then
    snapshot_primed=1
    break
  fi
  sleep 5
done

if [ "$snapshot_primed" -ne 1 ]; then
  log "The MQTT snapshot priming step failed; the GUI may still miss retained values."
fi

log "Venus OS local services are up; MK3-USB is mapped through $SERIAL_DEVICE."

wait "$SVSCANBOOT_PID"
