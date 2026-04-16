# Venus OS Local for Home Assistant

`Venus OS Local` runs Victron Venus OS as a Home Assistant add-on. The goal is simple: keep the Venus web UI, local MQTT, and Modbus TCP on the same machine as Home Assistant instead of needing a separate Venus GX device.

## What You Need

- Home Assistant OS on `aarch64`
- A Victron MK3-USB adapter
- A VE.Bus MultiPlus inverter
- Access to the Home Assistant host so you can copy this add-on into `/addons/local/`

This project is currently aimed at that setup. If you are using a different Victron hardware path, expect to do extra testing.

## What You Get

- Venus OS web UI in Home Assistant
- Home Assistant sidebar: `Victron VenusOS`
- `OPEN WEB UI` support from the add-on page
- Direct GUIv2 URL: `http://<home-assistant-host>/gui-v2/`
- Legacy root URL: `http://<home-assistant-host>/`
- Modbus TCP: `<home-assistant-host>:502`
- MQTT: `<home-assistant-host>:1883`
- MQTT over WebSocket: `ws://<home-assistant-host>/websocket-mqtt`

## Quick Start

1. In Home Assistant, go to `Settings > Add-ons > Add-on Store`.
2. Open the menu in the top-right and choose `Repositories`.
3. Add `https://github.com/usersaynoso/Victron-Venus-OS-for-Home-Assistant`.
4. Open `Venus OS Local`, go to `Configuration`, and select `serial_device`.
5. Start the add-on after a serial device is selected.
6. Use `OPEN WEB UI` or the `Victron VenusOS` sidebar entry to open Venus.

## Install in Home Assistant

This repository can now be added directly to Home Assistant as a custom add-on repository.

1. Open Home Assistant.
2. Go to `Settings > Add-ons > Add-on Store`.
3. Open the menu in the top-right and choose `Repositories`.
4. Paste this repository URL:

```sh
https://github.com/usersaynoso/Victron-Venus-OS-for-Home-Assistant
```

5. Confirm the repository was added.
6. Find `Venus OS Local` in the add-on store.
7. Open the add-on, go to `Configuration`, and select `serial_device`.
8. Start it after a serial device is selected.
9. Open it with `OPEN WEB UI` or from the `Victron VenusOS` sidebar item.

## Local Install Alternative

If you prefer not to add the GitHub repository in the UI, you can still install it locally on the Home Assistant host.

1. Get shell access to the Home Assistant host.
2. Create the local add-on folder if it does not already exist:

```sh
mkdir -p /addons/local/venus_local
```

3. Copy the contents of the `venus_local/` folder from this repository into `/addons/local/venus_local/`.
4. In Home Assistant, go to `Settings > Add-ons > Add-on Store`.
5. Open the menu in the top-right and choose `Reload`.
6. Open `Venus OS Local` from the add-on store.

## Add-on Option

Use a stable device path for `serial_device`.

Do not use `/dev/ttyUSB0`.

Use `/dev/serial/by-id/...` instead, for example:

```yaml
serial_device: /dev/serial/by-id/usb-VictronEnergy_MK3-USB_Interface_HQ22457CDAZ-if00-port0
```

You must select `serial_device` in the add-on `Configuration` tab before starting the add-on.
If no serial device is selected, the add-on will stay stopped and `OPEN WEB UI` will remain unavailable.

To check the device path on the Home Assistant host:

```sh
ls -l /dev/serial/by-id
```

## First Run Notes

- The first `gui-v2` load can take a little longer while values appear.
- Give the add-on about a minute on first start so retained MQTT values can populate.
- `OPEN WEB UI` goes to `/gui-v2/`.

## Troubleshooting

### The add-on does not appear in Home Assistant

- Make sure the add-on folder is exactly `/addons/local/venus_local/`.
- Reload the add-on store after copying the files.
- Confirm `config.yaml` is present in the top level of that folder.

### The UI does not open

- Check the add-on logs in Home Assistant.
- Confirm you selected `serial_device` in `Configuration` before starting the add-on.
- Make sure the host answers on port `80`.
- Try the direct URL: `http://<home-assistant-host>/gui-v2/`

### The UI opens but values are missing

- Confirm your `serial_device` path exists.
- Confirm the MK3-USB adapter is visible under `/dev/serial/by-id/`.
- Give the add-on another minute on first start so retained values can populate.

### Home Assistant says it started, but VE.Bus values are still missing

Look in the logs for messages that confirm the serial link and MQTT snapshot came up cleanly.

## Notes

- This is a local Home Assistant add-on, not an official Victron or Home Assistant add-on.
- It is focused on the MK3-USB plus VE.Bus use case on `aarch64`.
- Be careful when using control paths against real power equipment.
