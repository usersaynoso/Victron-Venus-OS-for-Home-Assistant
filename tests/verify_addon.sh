#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_DIR="${ROOT_DIR}/venus_local"
ROOT_README="${ROOT_DIR}/README.md"
ADDON_README="${ADDON_DIR}/README.md"

sh -n "${ADDON_DIR}/run.sh"

if [ ! -f "${ROOT_README}" ]; then
  echo "root README.md is required" >&2
  exit 1
fi

if [ ! -f "${ADDON_README}" ]; then
  echo "addon README.md is required" >&2
  exit 1
fi

if [ ! -f "${ADDON_DIR}/CHANGELOG.md" ]; then
  echo "addon CHANGELOG.md is required" >&2
  exit 1
fi

if [ ! -f "${ADDON_DIR}/icon.png" ]; then
  echo "addon icon.png is required" >&2
  exit 1
fi

if [ ! -f "${ADDON_DIR}/logo.png" ]; then
  echo "addon logo.png is required" >&2
  exit 1
fi

if [ ! -f "${ADDON_DIR}/dark_icon.png" ]; then
  echo "addon dark_icon.png is required" >&2
  exit 1
fi

if [ ! -f "${ADDON_DIR}/dark_logo.png" ]; then
  echo "addon dark_logo.png is required" >&2
  exit 1
fi

if [ ! -f "${ROOT_DIR}/repository.yaml" ]; then
  echo "repository.yaml is required" >&2
  exit 1
fi

ruby - "${ADDON_DIR}/config.yaml" <<'RUBY'
require "yaml"

config = YAML.load_file(ARGV.fetch(0))

raise "unexpected name" unless config["name"] == "Venus OS Local"
raise "unexpected version" unless config["version"] == "2.0.1"
raise "unexpected slug" unless config["slug"] == "venus_local"
raise "startup must be services" unless config["startup"] == "services"
raise "host_network must be enabled" unless config["host_network"] == true
raise "uart must be enabled" unless config["uart"] == true
raise "arch must include aarch64" unless Array(config["arch"]).include?("aarch64")
raise "webui must target gui-v2" unless config["webui"] == "http://[HOST]:[PORT:80]/gui-v2/"
raise "ingress must be enabled" unless config["ingress"] == true
raise "ingress_port must be 80" unless config["ingress_port"] == 80
raise "ingress_entry must target gui-v2" unless config["ingress_entry"] == "/gui-v2/"
raise "panel_title must be Victron VenusOS" unless config["panel_title"] == "Victron VenusOS"
raise "panel_icon must be mdi:flash" unless config["panel_icon"] == "mdi:flash"
raise "devices should not be hardcoded" if config.key?("devices")
raise "default options should require manual serial selection" unless config["options"] == { "serial_device" => nil }
raise "serial_device schema mismatch" unless config.dig("schema", "serial_device") == "device(subsystem=tty)"

expected_ports = {
  "80/tcp" => 80,
  "502/tcp" => 502,
  "1883/tcp" => 1883,
}
raise "ports mismatch" unless config["ports"] == expected_ports

expected_caps = %w[
  BPF
  CHECKPOINT_RESTORE
  DAC_READ_SEARCH
  IPC_LOCK
  NET_ADMIN
  NET_RAW
  PERFMON
  SYS_ADMIN
  SYS_MODULE
  SYS_NICE
  SYS_PTRACE
  SYS_RAWIO
  SYS_RESOURCE
  SYS_TIME
]

raise "privileged capabilities mismatch" unless Array(config["privileged"]).sort == expected_caps.sort
RUBY

ruby - "${ROOT_DIR}/repository.yaml" <<'RUBY'
require "yaml"

repo = YAML.load_file(ARGV.fetch(0))

raise "unexpected repository name" unless repo["name"] == "Victron Venus OS for Home Assistant"
raise "unexpected repository url" unless repo["url"] == "https://github.com/usersaynoso/Victron-Venus-OS-for-Home-Assistant"
raise "unexpected repository maintainer" unless repo["maintainer"] == "UserSayNoSo"
RUBY

python3 - "${ADDON_DIR}/icon.png" "${ADDON_DIR}/logo.png" "${ADDON_DIR}/dark_icon.png" "${ADDON_DIR}/dark_logo.png" <<'PY'
import struct
import sys
from pathlib import Path


def png_size(path_str):
    path = Path(path_str)
    data = path.read_bytes()
    signature = b"\x89PNG\r\n\x1a\n"
    if not data.startswith(signature):
        raise SystemExit(f"{path.name} is not a PNG")
    if data[12:16] != b"IHDR":
        raise SystemExit(f"{path.name} is missing an IHDR chunk")
    width, height = struct.unpack(">II", data[16:24])
    if width <= 0 or height <= 0:
        raise SystemExit(f"{path.name} has invalid dimensions")
    return width, height


icon_width, icon_height = png_size(sys.argv[1])
logo_width, logo_height = png_size(sys.argv[2])
dark_icon_width, dark_icon_height = png_size(sys.argv[3])
dark_logo_width, dark_logo_height = png_size(sys.argv[4])

if icon_width != icon_height:
    raise SystemExit("icon.png must remain square")

if dark_icon_width != dark_icon_height:
    raise SystemExit("dark_icon.png must remain square")

if logo_width <= 0 or logo_height <= 0:
    raise SystemExit("logo.png dimensions are invalid")

if dark_logo_width <= 0 or dark_logo_height <= 0:
    raise SystemExit("dark_logo.png dimensions are invalid")
PY

grep -Eq '^ARG BUILD_FROM=ubuntu:24.04$' "${ADDON_DIR}/Dockerfile"
grep -Eq '^FROM \$\{BUILD_FROM\} AS extract$' "${ADDON_DIR}/Dockerfile"
grep -Eq 'venus-swu-3-large-raspberrypi4\.swu' "${ADDON_DIR}/Dockerfile"
grep -Eq '^FROM scratch$' "${ADDON_DIR}/Dockerfile"
grep -Eq '^COPY run\.sh /run\.sh$' "${ADDON_DIR}/Dockerfile"
grep -Eq 'debugfs -R "rdump / /venus-rootfs"' "${ADDON_DIR}/Dockerfile"
if grep -Eq 'SERIAL_DEVICE=/dev/ttyUSB0' "${ADDON_DIR}/Dockerfile"; then
  echo "Dockerfile must not hardcode /dev/ttyUSB0" >&2
  exit 1
fi
grep -Eq '^ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket$' "${ADDON_DIR}/Dockerfile"
grep -Eq 'ln -sfn /run/service /venus-rootfs/service' "${ADDON_DIR}/Dockerfile"
grep -Eq 'ln -sfn /run/tmp /venus-rootfs/tmp' "${ADDON_DIR}/Dockerfile"
grep -Eq 'ln -sfn /run/log /venus-rootfs/var/log' "${ADDON_DIR}/Dockerfile"
grep -Eq 'ln -sfn /run /venus-rootfs/var/run' "${ADDON_DIR}/Dockerfile"
grep -Eq '^# Victron Venus OS for Home Assistant$' "${ROOT_README}"
grep -Eq 'Settings > Add-ons > Add-on Store' "${ROOT_README}"
grep -Eq 'choose `Repositories`' "${ROOT_README}"
grep -Eq 'https://github.com/usersaynoso/Victron-Venus-OS-for-Home-Assistant' "${ROOT_README}"
grep -Eq 'Configuration' "${ROOT_README}"
grep -Eq 'will not start or open the Web UI until a serial device is selected' "${ROOT_README}"
grep -Eq 'venus_local/README\.md' "${ROOT_README}"
grep -Eq '^# Venus OS Local for Home Assistant$' "${ADDON_README}"
grep -Eq '^# Changelog$' "${ADDON_DIR}/CHANGELOG.md"
grep -Eq '^## 2\.0\.1$' "${ADDON_DIR}/CHANGELOG.md"
grep -Eq 'Rename the Home Assistant sidebar entry to `Victron VenusOS`\.' "${ADDON_DIR}/CHANGELOG.md"
grep -Eq 'Bump the add-on version to `2\.0\.1`\.' "${ADDON_DIR}/CHANGELOG.md"
grep -Eq '^## 2\.0$' "${ADDON_DIR}/CHANGELOG.md"
grep -Eq 'Fix Home Assistant changelog support by shipping `CHANGELOG\.md` with the add-on\.' "${ADDON_DIR}/CHANGELOG.md"
grep -Eq '^## What You Need$' "${ADDON_README}"
grep -Eq '^## Quick Start$' "${ADDON_README}"
grep -Eq '^## Install in Home Assistant$' "${ADDON_README}"
grep -Eq '^## Local Install Alternative$' "${ADDON_README}"
grep -Eq 'serial_device' "${ADDON_README}"
grep -Eq 'Configuration' "${ADDON_README}"
grep -Eq 'must select `serial_device`' "${ADDON_README}"
grep -Eq 'Do not use `/dev/ttyUSB0`\.' "${ADDON_README}"
grep -Eq '/dev/serial/by-id/' "${ADDON_README}"
grep -Eq '/gui-v2/' "${ADDON_README}"
grep -Eq 'Home Assistant sidebar: `Victron VenusOS`' "${ADDON_README}"
grep -Eq '`OPEN WEB UI`' "${ADDON_README}"
grep -Eq '/addons/local/venus_local' "${ADDON_README}"
grep -Eq 'Settings > Add-ons > Add-on Store' "${ADDON_README}"
grep -Eq 'choose `Repositories`' "${ADDON_README}"
grep -Eq 'https://github.com/usersaynoso/Victron-Venus-OS-for-Home-Assistant' "${ADDON_README}"
grep -Eq '/websocket-mqtt' "${ADDON_README}"
grep -Eq 'Modbus TCP: `<home-assistant-host>:502`' "${ADDON_README}"
grep -Eq 'MQTT: `<home-assistant-host>:1883`' "${ADDON_README}"
test -x "${ADDON_DIR}/run.sh"
grep -Eq 'dbus-daemon --system --fork --nopidfile' "${ADDON_DIR}/run.sh"
grep -Eq 'alias default mkx' "${ADDON_DIR}/run.sh"
grep -Eq '^SVDIR="\$\{SVDIR:-/run/service\}"$' "${ADDON_DIR}/run.sh"
grep -Eq '^LOCALSETTINGS_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^SERIAL_SCAN_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^NGINX_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^FLASHMQ_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^DBUS_MQTT_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^MODBUSTCP_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^UNIQUE_ID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^SERIAL_TTY=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^SERIAL_STARTER_DEVICE_DIR="/run/serial-starter-devices"$' "${ADDON_DIR}/run.sh"
grep -Eq '^MK2_DBUS_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^SYSTEMCALC_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^PLATFORM_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^MQTT_BOOTSTRAP_PID=""$' "${ADDON_DIR}/run.sh"
grep -Eq '^SERIAL_DEVICE="\$\{SERIAL_DEVICE:-\}"$' "${ADDON_DIR}/run.sh"
grep -Eq 'localsettings\.py --path=/data/conf &' "${ADDON_DIR}/run.sh"
grep -Eq 'load_serial_device_from_options' "${ADDON_DIR}/run.sh"
grep -Eq 'ensure_gui_v2_ingress_compat' "${ADDON_DIR}/run.sh"
grep -Eq '/data/options\.json' "${ADDON_DIR}/run.sh"
grep -Eq '/dev/serial/by-id/' "${ADDON_DIR}/run.sh"
grep -Eq 'os\.path\.realpath' "${ADDON_DIR}/run.sh"
grep -Eq '/run/serial-starter-devices' "${ADDON_DIR}/run.sh"
grep -Eq 'Linked \$SERIAL_STARTER_DEVICE_DIR/' "${ADDON_DIR}/run.sh"
grep -Eq 'No serial device selected in Configuration\. Choose a stable path under /dev/serial/by-id/ before starting or opening the Web UI\.' "${ADDON_DIR}/run.sh"
grep -Eq '/data/conf/venus-local-unique-id' "${ADDON_DIR}/run.sh"
grep -Eq '/sbin/get-unique-id' "${ADDON_DIR}/run.sh"
grep -Eq 'Using unique VRM identifier' "${ADDON_DIR}/run.sh"
grep -Eq '/opt/victronenergy/dbus-mqtt/dbus_mqtt\.py' "${ADDON_DIR}/run.sh"
grep -Eq 'serial-starter/serial-starter\.sh' "${ADDON_DIR}/run.sh"
grep -Eq 'source.replace\(\"/dev/serial-starter\", device_dir\)' "${ADDON_DIR}/run.sh"
grep -Eq 'CallbackAPIVersion\.VERSION1' "${ADDON_DIR}/run.sh"
grep -Eq 'org\.freedesktop\.DBus\.NameHasOwner' "${ADDON_DIR}/run.sh"
grep -Eq 'svc -t "\$SVDIR/serial-starter"' "${ADDON_DIR}/run.sh"
grep -Eq 'serial-starter/serial-starter\.sh &' "${ADDON_DIR}/run.sh"
grep -Eq 'Generating a self-signed nginx certificate' "${ADDON_DIR}/run.sh"
grep -Eq '/data/etc/ssl/venus\.local\.key' "${ADDON_DIR}/run.sh"
grep -Eq '/data/etc/ssl/venus\.local\.crt' "${ADDON_DIR}/run.sh"
grep -Eq 'Starting FlashMQ directly' "${ADDON_DIR}/run.sh"
grep -Eq '/usr/sbin/start-flashmq &' "${ADDON_DIR}/run.sh"
grep -Eq 'Starting dbus-mqtt directly' "${ADDON_DIR}/run.sh"
grep -Eq 'dbus_mqtt\.py -k 31536000 &' "${ADDON_DIR}/run.sh"
grep -Eq 'Starting dbus-modbustcp directly' "${ADDON_DIR}/run.sh"
grep -Eq 'dbus-modbustcp &' "${ADDON_DIR}/run.sh"
grep -Eq 'Starting mk2-dbus directly on /dev/' "${ADDON_DIR}/run.sh"
grep -Eq '/opt/victronenergy/mk2-dbus/mk2-dbus \\' "${ADDON_DIR}/run.sh"
grep -Eq -- '--log-before 25' "${ADDON_DIR}/run.sh"
grep -Eq -- '--log-after 25' "${ADDON_DIR}/run.sh"
grep -Eq -- '-w \\' "${ADDON_DIR}/run.sh"
grep -Eq -- '-s "/dev/\$SERIAL_TTY" \\' "${ADDON_DIR}/run.sh"
grep -Eq -- '-t mk3 \\' "${ADDON_DIR}/run.sh"
grep -Eq -- '--settings "\$settings_file" &' "${ADDON_DIR}/run.sh"
grep -Eq 'Starting dbus-systemcalc directly' "${ADDON_DIR}/run.sh"
grep -Eq 'dbus_systemcalc\.py &' "${ADDON_DIR}/run.sh"
grep -Eq 'venus-platform/venus-platform' "${ADDON_DIR}/run.sh"
grep -Eq 'Starting venus-platform directly' "${ADDON_DIR}/run.sh"
grep -Eq 'Priming the local MQTT snapshot' "${ADDON_DIR}/run.sh"
grep -Eq 'R/\{system_id\}/keepalive' "${ADDON_DIR}/run.sh"
grep -Eq 'R/\{system_id\}/system/0/Serial' "${ADDON_DIR}/run.sh"
grep -Eq 'serial_topic = f"N/\{system_id\}/system/0/Serial"' "${ADDON_DIR}/run.sh"
grep -Eq 'received_serial = False' "${ADDON_DIR}/run.sh"
grep -Eq 'The local MQTT snapshot is primed' "${ADDON_DIR}/run.sh"
grep -Eq "request.get\\('topics'\\)" "${ADDON_DIR}/run.sh"
grep -Eq 'Republishing retained MQTT bootstrap topics during startup' "${ADDON_DIR}/run.sh"
grep -Eq 'venus-local-bootstrap' "${ADDON_DIR}/run.sh"
grep -Fq "const ingressBasePath = window.location.pathname.replace(" "${ADDON_DIR}/run.sh"
grep -Fq "const mqttPath = (ingressBasePath ? ingressBasePath : '') + '/websocket-mqtt';" "${ADDON_DIR}/run.sh"
grep -Fq "document.location.host + mqttPath" "${ADDON_DIR}/run.sh"
grep -Fq "const auxHost = document.location.hostname;" "${ADDON_DIR}/run.sh"
grep -Eq 'N/\{system_id\}/system/0/Serial' "${ADDON_DIR}/run.sh"
grep -Eq 'N/\{system_id\}/keepalive' "${ADDON_DIR}/run.sh"
grep -Eq 'for _ in range\(30\)' "${ADDON_DIR}/run.sh"
grep -Eq 'time\.sleep\(2\)' "${ADDON_DIR}/run.sh"
grep -Eq 'settings/0/Settings/System/Units/Temperature' "${ADDON_DIR}/run.sh"
grep -Eq 'settings/0/Settings/System/Units/Altitude' "${ADDON_DIR}/run.sh"
grep -Eq 'settings/0/Settings/System/VolumeUnit' "${ADDON_DIR}/run.sh"
grep -Eq 'settings/0/Settings/Gui/ElectricalPowerIndicator' "${ADDON_DIR}/run.sh"
grep -Eq 'The MQTT snapshot priming step failed; the GUI may still miss retained values' "${ADDON_DIR}/run.sh"
grep -Eq 'client_max_write_buffer_size 8388608' "${ADDON_DIR}/run.sh"
grep -Eq 'include_dir /run/flashmq' "${ADDON_DIR}/run.sh"
grep -Eq 'allow_anonymous true' "${ADDON_DIR}/run.sh"
grep -Eq 'zero_byte_username_is_anonymous true' "${ADDON_DIR}/run.sh"
grep -Eq 'protocol mqtt' "${ADDON_DIR}/run.sh"
grep -Eq 'port 8883' "${ADDON_DIR}/run.sh"
grep -Eq 'fullchain /data/keys/mosquitto\.crt' "${ADDON_DIR}/run.sh"
grep -Eq 'privkey /data/keys/mosquitto\.key' "${ADDON_DIR}/run.sh"
if grep -Eq 'plugin_opt_skip_broker_registration true' "${ADDON_DIR}/run.sh"; then
  echo "run.sh must not rely on VRM broker registration for the local add-on" >&2
  exit 1
fi
if grep -Eq 'libflashmq-dbus-plugin\.so' "${ADDON_DIR}/run.sh"; then
  echo "run.sh must not load the FlashMQ VRM auth plugin for the local add-on" >&2
  exit 1
fi
grep -Eq '/run/log' "${ADDON_DIR}/run.sh"
grep -Eq '/run/nginx' "${ADDON_DIR}/run.sh"
grep -Eq '/run/service' "${ADDON_DIR}/run.sh"
grep -Eq '/run/tmp' "${ADDON_DIR}/run.sh"
grep -Eq '/run/flashmq' "${ADDON_DIR}/run.sh"
grep -Eq '/var/volatile/log/nginx' "${ADDON_DIR}/run.sh"
grep -Eq '/var/volatile/log' "${ADDON_DIR}/run.sh"
grep -Eq 'wait_for_port 80 "Nginx Web UI"' "${ADDON_DIR}/run.sh"
grep -Eq 'Testing nginx configuration' "${ADDON_DIR}/run.sh"
grep -Eq 'nginx configuration test failed' "${ADDON_DIR}/run.sh"
grep -Eq 'Starting nginx directly' "${ADDON_DIR}/run.sh"
grep -Eq '/usr/sbin/nginx &' "${ADDON_DIR}/run.sh"
grep -Eq 'mk2-dbus did not start; leaving the web UI up for inspection' "${ADDON_DIR}/run.sh"
grep -Eq 'wait_for_port 1883 "FlashMQ" 30' "${ADDON_DIR}/run.sh"
grep -Eq 'wait_for_port 9001 "FlashMQ WebSockets" 30' "${ADDON_DIR}/run.sh"
grep -Eq 'wait_for_port 502 "Modbus TCP" 30' "${ADDON_DIR}/run.sh"
grep -Eq 'FlashMQ is not ready yet; continuing so the web UI remains available' "${ADDON_DIR}/run.sh"
grep -Eq 'FlashMQ WebSockets are not ready yet; the GUI may still fail to connect' "${ADDON_DIR}/run.sh"
grep -Eq 'Modbus TCP is not ready yet; continuing so the web UI remains available' "${ADDON_DIR}/run.sh"
grep -Eq 'Ignore AC Input registers are ready to vibe' "${ADDON_DIR}/run.sh"
if grep -Eq '^enable_service serial-starter ' "${ADDON_DIR}/run.sh"; then
  echo "run.sh must not enable serial-starter alongside direct mk2-dbus startup" >&2
  exit 1
fi
if grep -Eq 'autodetect_serial_device' "${ADDON_DIR}/run.sh"; then
  echo "run.sh must not auto-detect a serial device; the user must select it in Configuration" >&2
  exit 1
fi
if grep -Eq '^restart_serial_starter \|\| true$' "${ADDON_DIR}/run.sh"; then
  echo "run.sh must not restart serial-starter alongside direct mk2-dbus startup" >&2
  exit 1
fi
if grep -Eq '^  trigger_serial_scan$' "${ADDON_DIR}/run.sh"; then
  echo "run.sh must not trigger manual serial scans alongside direct mk2-dbus startup" >&2
  exit 1
fi

nginx_prep_line="$(grep -n 'ensure_nginx_prereqs || true' "${ADDON_DIR}/run.sh" | cut -d: -f1)"
flashmq_prep_line="$(grep -n 'ensure_flashmq_config' "${ADDON_DIR}/run.sh" | tail -n 1 | cut -d: -f1)"
svscanboot_line="$(grep -n 'svscan "\$SVDIR" &' "${ADDON_DIR}/run.sh" | cut -d: -f1)"

if [ -z "${nginx_prep_line}" ] || [ -z "${flashmq_prep_line}" ] || [ -z "${svscanboot_line}" ]; then
  echo "Unable to verify service startup ordering in run.sh" >&2
  exit 1
fi

if [ "${nginx_prep_line}" -ge "${svscanboot_line}" ] || [ "${flashmq_prep_line}" -ge "${svscanboot_line}" ]; then
  echo "run.sh must prepare nginx and flashmq before starting svscanboot" >&2
  exit 1
fi

echo "Addon file checks passed."
