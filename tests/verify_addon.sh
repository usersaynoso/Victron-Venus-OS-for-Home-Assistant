#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sh -n "${ROOT_DIR}/run.sh"

if [ ! -f "${ROOT_DIR}/README.md" ]; then
  echo "README.md is required" >&2
  exit 1
fi

ruby - "${ROOT_DIR}/config.yaml" <<'RUBY'
require "yaml"

config = YAML.load_file(ARGV.fetch(0))

raise "unexpected name" unless config["name"] == "Venus OS Local"
raise "unexpected slug" unless config["slug"] == "venus_local"
raise "startup must be services" unless config["startup"] == "services"
raise "host_network must be enabled" unless config["host_network"] == true
raise "uart must be enabled" unless config["uart"] == true
raise "arch must include aarch64" unless Array(config["arch"]).include?("aarch64")
raise "webui must target gui-v2" unless config["webui"] == "http://[HOST]:[PORT:80]/gui-v2/"
raise "ingress must be enabled" unless config["ingress"] == true
raise "ingress_port must be 80" unless config["ingress_port"] == 80
raise "ingress_entry must target gui-v2" unless config["ingress_entry"] == "/gui-v2/"
raise "panel_title must be Victron" unless config["panel_title"] == "Victron"
raise "panel_icon must be mdi:flash" unless config["panel_icon"] == "mdi:flash"
raise "devices should not be hardcoded" if config.key?("devices")
raise "default options should be empty" unless config["options"] == {}
raise "serial_device schema mismatch" unless config.dig("schema", "serial_device") == "device(subsystem=tty)?"

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

grep -Eq '^ARG BUILD_FROM=ubuntu:24.04$' "${ROOT_DIR}/Dockerfile"
grep -Eq '^FROM \$\{BUILD_FROM\} AS extract$' "${ROOT_DIR}/Dockerfile"
grep -Eq 'venus-swu-3-large-raspberrypi4\.swu' "${ROOT_DIR}/Dockerfile"
grep -Eq '^FROM scratch$' "${ROOT_DIR}/Dockerfile"
grep -Eq '^COPY run\.sh /run\.sh$' "${ROOT_DIR}/Dockerfile"
grep -Eq 'debugfs -R "rdump / /venus-rootfs"' "${ROOT_DIR}/Dockerfile"
if grep -Eq 'SERIAL_DEVICE=/dev/ttyUSB0' "${ROOT_DIR}/Dockerfile"; then
  echo "Dockerfile must not hardcode /dev/ttyUSB0" >&2
  exit 1
fi
grep -Eq '^ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket$' "${ROOT_DIR}/Dockerfile"
grep -Eq 'ln -sfn /run/service /venus-rootfs/service' "${ROOT_DIR}/Dockerfile"
grep -Eq 'ln -sfn /run/tmp /venus-rootfs/tmp' "${ROOT_DIR}/Dockerfile"
grep -Eq 'ln -sfn /run/log /venus-rootfs/var/log' "${ROOT_DIR}/Dockerfile"
grep -Eq 'ln -sfn /run /venus-rootfs/var/run' "${ROOT_DIR}/Dockerfile"
grep -Eq '^# Venus OS Local for Home Assistant$' "${ROOT_DIR}/README.md"
grep -Eq '^## What You Need$' "${ROOT_DIR}/README.md"
grep -Eq '^## Quick Start$' "${ROOT_DIR}/README.md"
grep -Eq 'serial_device' "${ROOT_DIR}/README.md"
grep -Eq 'Do not use `/dev/ttyUSB0`\.' "${ROOT_DIR}/README.md"
grep -Eq '/dev/serial/by-id/' "${ROOT_DIR}/README.md"
grep -Eq '/gui-v2/' "${ROOT_DIR}/README.md"
grep -Eq 'Home Assistant sidebar: `Victron`' "${ROOT_DIR}/README.md"
grep -Eq '/websocket-mqtt' "${ROOT_DIR}/README.md"
grep -Eq 'Modbus TCP: `<home-assistant-host>:502`' "${ROOT_DIR}/README.md"
grep -Eq 'MQTT: `<home-assistant-host>:1883`' "${ROOT_DIR}/README.md"
test -x "${ROOT_DIR}/run.sh"
grep -Eq 'dbus-daemon --system --fork --nopidfile' "${ROOT_DIR}/run.sh"
grep -Eq 'alias default mkx' "${ROOT_DIR}/run.sh"
grep -Eq '^SVDIR="\$\{SVDIR:-/run/service\}"$' "${ROOT_DIR}/run.sh"
grep -Eq '^LOCALSETTINGS_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^SERIAL_SCAN_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^NGINX_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^FLASHMQ_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^DBUS_MQTT_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^MODBUSTCP_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^UNIQUE_ID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^SERIAL_TTY=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^SERIAL_STARTER_DEVICE_DIR="/run/serial-starter-devices"$' "${ROOT_DIR}/run.sh"
grep -Eq '^MK2_DBUS_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^SYSTEMCALC_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^PLATFORM_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^MQTT_BOOTSTRAP_PID=""$' "${ROOT_DIR}/run.sh"
grep -Eq '^SERIAL_DEVICE="\$\{SERIAL_DEVICE:-\}"$' "${ROOT_DIR}/run.sh"
grep -Eq 'localsettings\.py --path=/data/conf &' "${ROOT_DIR}/run.sh"
grep -Eq 'load_serial_device_from_options' "${ROOT_DIR}/run.sh"
grep -Eq 'autodetect_serial_device' "${ROOT_DIR}/run.sh"
grep -Eq 'ensure_gui_v2_ingress_compat' "${ROOT_DIR}/run.sh"
grep -Eq '/data/options\.json' "${ROOT_DIR}/run.sh"
grep -Eq '/dev/serial/by-id/' "${ROOT_DIR}/run.sh"
grep -Eq 'os\.path\.realpath' "${ROOT_DIR}/run.sh"
grep -Eq '/run/serial-starter-devices' "${ROOT_DIR}/run.sh"
grep -Eq 'Linked \$SERIAL_STARTER_DEVICE_DIR/' "${ROOT_DIR}/run.sh"
grep -Eq 'No serial device configured\. Set the add-on serial_device option' "${ROOT_DIR}/run.sh"
grep -Eq '/data/conf/venus-local-unique-id' "${ROOT_DIR}/run.sh"
grep -Eq '/sbin/get-unique-id' "${ROOT_DIR}/run.sh"
grep -Eq 'Using unique VRM identifier' "${ROOT_DIR}/run.sh"
grep -Eq '/opt/victronenergy/dbus-mqtt/dbus_mqtt\.py' "${ROOT_DIR}/run.sh"
grep -Eq 'serial-starter/serial-starter\.sh' "${ROOT_DIR}/run.sh"
grep -Eq 'source.replace\(\"/dev/serial-starter\", device_dir\)' "${ROOT_DIR}/run.sh"
grep -Eq 'CallbackAPIVersion\.VERSION1' "${ROOT_DIR}/run.sh"
grep -Eq 'org\.freedesktop\.DBus\.NameHasOwner' "${ROOT_DIR}/run.sh"
grep -Eq 'svc -t "\$SVDIR/serial-starter"' "${ROOT_DIR}/run.sh"
grep -Eq 'serial-starter/serial-starter\.sh &' "${ROOT_DIR}/run.sh"
grep -Eq 'Generating a self-signed nginx certificate' "${ROOT_DIR}/run.sh"
grep -Eq '/data/etc/ssl/venus\.local\.key' "${ROOT_DIR}/run.sh"
grep -Eq '/data/etc/ssl/venus\.local\.crt' "${ROOT_DIR}/run.sh"
grep -Eq 'Starting FlashMQ directly' "${ROOT_DIR}/run.sh"
grep -Eq '/usr/sbin/start-flashmq &' "${ROOT_DIR}/run.sh"
grep -Eq 'Starting dbus-mqtt directly' "${ROOT_DIR}/run.sh"
grep -Eq 'dbus_mqtt\.py -k 31536000 &' "${ROOT_DIR}/run.sh"
grep -Eq 'Starting dbus-modbustcp directly' "${ROOT_DIR}/run.sh"
grep -Eq 'dbus-modbustcp &' "${ROOT_DIR}/run.sh"
grep -Eq 'Starting mk2-dbus directly on /dev/' "${ROOT_DIR}/run.sh"
grep -Eq '/opt/victronenergy/mk2-dbus/mk2-dbus \\' "${ROOT_DIR}/run.sh"
grep -Eq -- '--log-before 25' "${ROOT_DIR}/run.sh"
grep -Eq -- '--log-after 25' "${ROOT_DIR}/run.sh"
grep -Eq -- '-w \\' "${ROOT_DIR}/run.sh"
grep -Eq -- '-s "/dev/\$SERIAL_TTY" \\' "${ROOT_DIR}/run.sh"
grep -Eq -- '-t mk3 \\' "${ROOT_DIR}/run.sh"
grep -Eq -- '--settings "\$settings_file" &' "${ROOT_DIR}/run.sh"
grep -Eq 'Starting dbus-systemcalc directly' "${ROOT_DIR}/run.sh"
grep -Eq 'dbus_systemcalc\.py &' "${ROOT_DIR}/run.sh"
grep -Eq 'venus-platform/venus-platform' "${ROOT_DIR}/run.sh"
grep -Eq 'Starting venus-platform directly' "${ROOT_DIR}/run.sh"
grep -Eq 'Priming the local MQTT snapshot' "${ROOT_DIR}/run.sh"
grep -Eq 'R/\{system_id\}/keepalive' "${ROOT_DIR}/run.sh"
grep -Eq 'R/\{system_id\}/system/0/Serial' "${ROOT_DIR}/run.sh"
grep -Eq 'serial_topic = f"N/\{system_id\}/system/0/Serial"' "${ROOT_DIR}/run.sh"
grep -Eq 'received_serial = False' "${ROOT_DIR}/run.sh"
grep -Eq 'The local MQTT snapshot is primed' "${ROOT_DIR}/run.sh"
grep -Eq "request.get\\('topics'\\)" "${ROOT_DIR}/run.sh"
grep -Eq 'Republishing retained MQTT bootstrap topics during startup' "${ROOT_DIR}/run.sh"
grep -Eq 'venus-local-bootstrap' "${ROOT_DIR}/run.sh"
grep -Fq "const ingressBasePath = window.location.pathname.replace(" "${ROOT_DIR}/run.sh"
grep -Fq "const mqttPath = (ingressBasePath ? ingressBasePath : '') + '/websocket-mqtt';" "${ROOT_DIR}/run.sh"
grep -Fq "document.location.host + mqttPath" "${ROOT_DIR}/run.sh"
grep -Fq "const auxHost = document.location.hostname;" "${ROOT_DIR}/run.sh"
grep -Eq 'N/\{system_id\}/system/0/Serial' "${ROOT_DIR}/run.sh"
grep -Eq 'N/\{system_id\}/keepalive' "${ROOT_DIR}/run.sh"
grep -Eq 'for _ in range\(30\)' "${ROOT_DIR}/run.sh"
grep -Eq 'time\.sleep\(2\)' "${ROOT_DIR}/run.sh"
grep -Eq 'settings/0/Settings/System/Units/Temperature' "${ROOT_DIR}/run.sh"
grep -Eq 'settings/0/Settings/System/Units/Altitude' "${ROOT_DIR}/run.sh"
grep -Eq 'settings/0/Settings/System/VolumeUnit' "${ROOT_DIR}/run.sh"
grep -Eq 'settings/0/Settings/Gui/ElectricalPowerIndicator' "${ROOT_DIR}/run.sh"
grep -Eq 'The MQTT snapshot priming step failed; the GUI may still miss retained values' "${ROOT_DIR}/run.sh"
grep -Eq 'client_max_write_buffer_size 8388608' "${ROOT_DIR}/run.sh"
grep -Eq 'include_dir /run/flashmq' "${ROOT_DIR}/run.sh"
grep -Eq 'allow_anonymous true' "${ROOT_DIR}/run.sh"
grep -Eq 'zero_byte_username_is_anonymous true' "${ROOT_DIR}/run.sh"
grep -Eq 'protocol mqtt' "${ROOT_DIR}/run.sh"
grep -Eq 'port 8883' "${ROOT_DIR}/run.sh"
grep -Eq 'fullchain /data/keys/mosquitto\.crt' "${ROOT_DIR}/run.sh"
grep -Eq 'privkey /data/keys/mosquitto\.key' "${ROOT_DIR}/run.sh"
if grep -Eq 'plugin_opt_skip_broker_registration true' "${ROOT_DIR}/run.sh"; then
  echo "run.sh must not rely on VRM broker registration for the local add-on" >&2
  exit 1
fi
if grep -Eq 'libflashmq-dbus-plugin\.so' "${ROOT_DIR}/run.sh"; then
  echo "run.sh must not load the FlashMQ VRM auth plugin for the local add-on" >&2
  exit 1
fi
grep -Eq '/run/log' "${ROOT_DIR}/run.sh"
grep -Eq '/run/nginx' "${ROOT_DIR}/run.sh"
grep -Eq '/run/service' "${ROOT_DIR}/run.sh"
grep -Eq '/run/tmp' "${ROOT_DIR}/run.sh"
grep -Eq '/run/flashmq' "${ROOT_DIR}/run.sh"
grep -Eq '/var/volatile/log/nginx' "${ROOT_DIR}/run.sh"
grep -Eq '/var/volatile/log' "${ROOT_DIR}/run.sh"
grep -Eq 'wait_for_port 80 "Nginx Web UI"' "${ROOT_DIR}/run.sh"
grep -Eq 'Testing nginx configuration' "${ROOT_DIR}/run.sh"
grep -Eq 'nginx configuration test failed' "${ROOT_DIR}/run.sh"
grep -Eq 'Starting nginx directly' "${ROOT_DIR}/run.sh"
grep -Eq '/usr/sbin/nginx &' "${ROOT_DIR}/run.sh"
grep -Eq 'mk2-dbus did not start; leaving the web UI up for inspection' "${ROOT_DIR}/run.sh"
grep -Eq 'wait_for_port 1883 "FlashMQ" 30' "${ROOT_DIR}/run.sh"
grep -Eq 'wait_for_port 9001 "FlashMQ WebSockets" 30' "${ROOT_DIR}/run.sh"
grep -Eq 'wait_for_port 502 "Modbus TCP" 30' "${ROOT_DIR}/run.sh"
grep -Eq 'FlashMQ is not ready yet; continuing so the web UI remains available' "${ROOT_DIR}/run.sh"
grep -Eq 'FlashMQ WebSockets are not ready yet; the GUI may still fail to connect' "${ROOT_DIR}/run.sh"
grep -Eq 'Modbus TCP is not ready yet; continuing so the web UI remains available' "${ROOT_DIR}/run.sh"
grep -Eq 'Ignore AC Input registers are ready to vibe' "${ROOT_DIR}/run.sh"
if grep -Eq '^enable_service serial-starter ' "${ROOT_DIR}/run.sh"; then
  echo "run.sh must not enable serial-starter alongside direct mk2-dbus startup" >&2
  exit 1
fi
if grep -Eq '^restart_serial_starter \|\| true$' "${ROOT_DIR}/run.sh"; then
  echo "run.sh must not restart serial-starter alongside direct mk2-dbus startup" >&2
  exit 1
fi
if grep -Eq '^  trigger_serial_scan$' "${ROOT_DIR}/run.sh"; then
  echo "run.sh must not trigger manual serial scans alongside direct mk2-dbus startup" >&2
  exit 1
fi

nginx_prep_line="$(grep -n 'ensure_nginx_prereqs || true' "${ROOT_DIR}/run.sh" | cut -d: -f1)"
flashmq_prep_line="$(grep -n 'ensure_flashmq_config' "${ROOT_DIR}/run.sh" | tail -n 1 | cut -d: -f1)"
svscanboot_line="$(grep -n 'svscan "\$SVDIR" &' "${ROOT_DIR}/run.sh" | cut -d: -f1)"

if [ -z "${nginx_prep_line}" ] || [ -z "${flashmq_prep_line}" ] || [ -z "${svscanboot_line}" ]; then
  echo "Unable to verify service startup ordering in run.sh" >&2
  exit 1
fi

if [ "${nginx_prep_line}" -ge "${svscanboot_line}" ] || [ "${flashmq_prep_line}" -ge "${svscanboot_line}" ]; then
  echo "run.sh must prepare nginx and flashmq before starting svscanboot" >&2
  exit 1
fi

echo "Addon file checks passed."
