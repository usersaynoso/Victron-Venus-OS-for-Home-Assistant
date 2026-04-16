# Venus OS Local for Home Assistant

Run a local Victron Venus OS stack as a Home Assistant add-on with direct MK3-USB access to a VE.Bus MultiPlus inverter.

This project packages a Venus OS root filesystem inside a Home Assistant add-on image, then starts the critical Victron services directly so the web UI, MQTT bridge, Modbus TCP server, and VE.Bus integration stay available on Home Assistant OS.

## What This Add-on Does

- Extracts a Venus OS Large root filesystem from Victron's Raspberry Pi 4 SWU image.
- Exposes the Venus web UI on port `80`.
- Exposes Modbus TCP on port `502`.
- Exposes local MQTT on port `1883`.
- Starts `mk2-dbus`, `dbus-mqtt`, `dbus-systemcalc`, `dbus-modbustcp`, `venus-platform`, `nginx`, and `php-fpm` inside the add-on.
- Bridges a physical MK3-USB adapter into the add-on without hardcoding `/dev/ttyUSB0`.

## Current Status

The add-on is currently targeted at:

- Home Assistant OS
- `aarch64`
- A Victron MK3-USB adapter connected to a VE.Bus MultiPlus inverter

The launcher includes compatibility patches for current MQTT client libraries and GUIv2 keepalive behavior so the GUI can keep its retained readings and settings instead of dropping out after the first minute.

## Why This Exists

A plain Venus root filesystem does not start cleanly inside Home Assistant OS by itself. The main issues this repo handles are:

- Venus runtime paths that need to be writable inside an add-on container
- Nginx and PHP startup inside Home Assistant's container environment
- Stable serial device selection
- `dbus-mqtt` compatibility with newer `paho-mqtt`
- GUIv2 retained topic bootstrap and keepalive behavior
- Local MQTT operation without VRM broker registration

## Features

- Stable serial configuration via add-on option `serial_device`
- Automatic fallback detection under `/dev/serial/by-id/`
- Host networking for a Venus-like network surface
- Self-signed certificate generation for internal Venus services
- Direct service startup instead of relying on every upstream service wrapper to behave inside HAOS
- MQTT bootstrap seeding so the GUI can discover the local system ID and retained values
- Long-lived `dbus-mqtt` keepalive interval to stop readings expiring after 60 seconds

## Repository Layout

- `Dockerfile`: extracts the Victron SWU image and prepares the runtime filesystem
- `config.yaml`: Home Assistant add-on manifest
- `run.sh`: container launcher and compatibility logic
- `tests/verify_addon.sh`: smoke checks for the image, manifest, launcher, and key runtime assumptions

## Installation

This repo is intended to be used as a local Home Assistant add-on repository or as the contents of a single local add-on directory.

### Local Add-on Directory

1. Copy this directory to your Home Assistant add-ons path, typically:
   `/addons/local/venus_local`
2. In Home Assistant, reload the local add-on store.
3. Open the `Venus OS Local` add-on.
4. Set the `serial_device` option to your MK3-USB adapter.
5. Start the add-on.

### Recommended Serial Device Configuration

Do not use `/dev/ttyUSB0`.

Use a stable by-id path instead, for example:

```yaml
serial_device: /dev/serial/by-id/usb-VictronEnergy_MK3-USB_Interface_HQ22457CDAZ-if00-port0
```

If `serial_device` is not set, the launcher will try to auto-detect a Victron device under `/dev/serial/by-id/`.

## Home Assistant Add-on Configuration

The add-on currently exposes one user option:

```yaml
serial_device: /dev/serial/by-id/usb-VictronEnergy_MK3-USB_Interface_HQ22457CDAZ-if00-port0
```

Manifest highlights:

- `host_network: true`
- `uart: true`
- `udev: true`
- `startup: services`
- `boot: auto`

## Exposed Interfaces

- Web UI: `http://<home-assistant-host>/`
- GUIv2: `http://<home-assistant-host>/gui-v2/`
- Modbus TCP: `<home-assistant-host>:502`
- MQTT: `<home-assistant-host>:1883`
- MQTT over WebSocket, via nginx: `ws://<home-assistant-host>/websocket-mqtt`

## Startup Flow

At container startup the launcher:

1. Loads `serial_device` from `/data/options.json` if configured.
2. Falls back to `/dev/serial/by-id/*` auto-detection when possible.
3. Resolves the real kernel tty behind the configured by-id device.
4. Prepares writable runtime directories under `/run`.
5. Generates a self-signed nginx certificate if needed.
6. Starts system D-Bus if it is missing.
7. Starts `localsettings`.
8. Starts `php-fpm`, `nginx`, `mk2-dbus`, `venus-platform`, `FlashMQ`, `dbus-mqtt`, `dbus-modbustcp`, and `dbus-systemcalc`.
9. Waits for the VE.Bus and D-Bus services to appear.
10. Republishes retained bootstrap MQTT topics and primes a local snapshot so GUIv2 can discover the system and populate settings and readings.

## Important Compatibility Fixes in This Repo

### Runtime filesystem fixes

The Venus root filesystem is extracted into the image, but the launcher and image also redirect runtime state into `/run` so the add-on can write logs, pid files, sockets, and service links without corrupting the rootfs.

### Stable serial device handling

The add-on no longer hardcodes `/dev/ttyUSB0`. The Home Assistant option uses `serial_device`, and the launcher resolves the real tty behind the configured `/dev/serial/by-id/...` symlink at runtime.

### GUI and MQTT reliability fixes

The launcher patches upstream `dbus-mqtt` files at runtime to:

- handle `paho-mqtt` 2.x callback API changes
- handle GUIv2 keepalive requests that send a JSON object instead of the older topic list payload
- keep retained MQTT publications alive long enough for the GUI to remain populated

It also seeds the MQTT bootstrap topics the GUI expects during first connection.

### Web UI resilience

If the vendor service path does not bring nginx up cleanly inside the add-on, the launcher tests the nginx configuration and starts nginx directly as a fallback so the Venus web UI stays reachable.

## Usage Notes

- First load of `gui-v2` can take a bit longer than the plain HTML shell. Give it time to hydrate from retained MQTT data.
- The add-on is designed around a local-only deployment on the Home Assistant box.
- `gui-v1` and `gui-v2` are both present in the Venus web stack, but the main validation focus in this repo is `gui-v2`.

## Troubleshooting

### The add-on starts but there is no web UI

Check:

- Home Assistant add-on logs
- whether port `80` is answering on the host
- whether nginx configuration tests pass inside the launcher logs

### The GUI shell appears but values are missing

Check:

- that the configured `serial_device` exists
- that `mk2-dbus` came up
- that `dbus-mqtt` connected to the local broker
- that `/websocket-mqtt` is reachable through nginx

The launcher already includes bootstrap republishing and MQTT snapshot priming to deal with the blank-GUI problem seen during early startup.

### Settings or controls disappear after about a minute

That was caused by retained MQTT state expiring too aggressively and by GUIv2 keepalive payloads not matching what upstream `dbus-mqtt` expected. This repo patches that behavior in `run.sh`.

### The configured serial device is missing

Use a persistent by-id device path and confirm the MK3-USB adapter is visible under:

```sh
ls -l /dev/serial/by-id
```

### Home Assistant says the add-on is started but VE.Bus values are missing

Look for:

- `mk2-dbus is running`
- `VE.Bus service is ready on D-Bus`
- `The local MQTT snapshot is primed`

in the add-on logs.

## Development

### Local verification

Run:

```sh
bash tests/verify_addon.sh
sh -n run.sh
```

The smoke test checks the manifest, the Dockerfile assumptions, and the launcher logic that keeps the GUI and MQTT bridge working.

### Updating the embedded Venus build

The SWU image is pinned in `Dockerfile`:

- image directory: `raspberrypi4`
- package: `venus-swu-3-large-raspberrypi4.swu`

If you change the upstream Venus image, re-run the repo checks and verify the launcher patches still apply cleanly.

## Known Limitations

- This repo is focused on a local VE.Bus / MK3-USB use case, not every possible Victron topology.
- The image currently targets `aarch64` Home Assistant OS.
- The runtime patches assume the relevant upstream Victron files still exist at the same paths.

## Safety Notes

- This project is not an official Victron or Home Assistant add-on.
- Be careful when using writable settings and control paths against real power equipment.
- Prefer explicit testing before relying on the setup for unattended operation.
