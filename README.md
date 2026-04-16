# Venus OS Local for Home Assistant

Run Victron Venus OS locally as a Home Assistant add-on.

This add-on is for people who want the Venus web UI, local MQTT, and Modbus TCP on their Home Assistant box without setting up a separate Venus device.

## What You Need

- Home Assistant OS
- `aarch64`
- A Victron MK3-USB adapter
- A VE.Bus MultiPlus inverter

This project is currently aimed at that setup. If you are using a different Victron hardware path, expect to do extra testing.

## What It Gives You

- Venus OS web UI in Home Assistant
- Home Assistant sidebar: `Victron`
- Direct GUIv2 URL: `http://<home-assistant-host>/gui-v2/`
- Legacy root URL: `http://<home-assistant-host>/`
- Modbus TCP: `<home-assistant-host>:502`
- MQTT: `<home-assistant-host>:1883`
- MQTT over WebSocket: `ws://<home-assistant-host>/websocket-mqtt`

## Quick Start

1. Copy this add-on into your Home Assistant local add-ons folder, usually:
   `/addons/local/venus_local`
2. In Home Assistant, reload the local add-on store.
3. Open `Venus OS Local`.
4. Set `serial_device` to your MK3-USB adapter.
5. Start the add-on.
6. Open it from `OPEN WEB UI` or from the `Victron` item in the Home Assistant sidebar.

## Add-on Option

Use a stable device path for `serial_device`.

Do not use `/dev/ttyUSB0`.

Use `/dev/serial/by-id/...` instead, for example:

```yaml
serial_device: /dev/serial/by-id/usb-VictronEnergy_MK3-USB_Interface_HQ22457CDAZ-if00-port0
```

If you leave `serial_device` blank, the add-on will try to auto-detect a matching device under `/dev/serial/by-id/`.

## First Run Notes

- The first `gui-v2` load can take a little longer while values appear.
- The add-on is meant to run locally on the Home Assistant machine.
- `OPEN WEB UI` goes to `/gui-v2/`.

## Troubleshooting

### The UI does not open

- Check the add-on logs in Home Assistant.
- Make sure the host answers on port `80`.
- Try the direct URL: `http://<home-assistant-host>/gui-v2/`

### The UI opens but values are missing

- Confirm your `serial_device` path exists.
- Confirm the MK3-USB adapter is visible under `/dev/serial/by-id/`.
- Give the add-on another minute on first start so retained values can populate.

To check the device path on the Home Assistant host:

```sh
ls -l /dev/serial/by-id
```

### Home Assistant says it started, but VE.Bus values are still missing

Look in the logs for messages that confirm the serial link and MQTT snapshot came up cleanly.

## Notes

- This is a local Home Assistant add-on, not an official Victron or Home Assistant add-on.
- It is focused on the MK3-USB plus VE.Bus use case on `aarch64`.
- Be careful when using control paths against real power equipment.
