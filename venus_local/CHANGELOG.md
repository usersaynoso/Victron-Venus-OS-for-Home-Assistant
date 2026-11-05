# Changelog

## 2.0.3

- Fix the boot loop on Venus OS v3.85 and later (`Required path is missing: /opt/victronenergy/dbus-mqtt/mqtt_gobject_bridge.py`). Victron removed dbus-mqtt from the image, so the build now restores dbus-mqtt v1.36 from Victron's GitHub when it is missing.
- Update the sidebar MQTT connection patch so it still applies to the reshuffled GUIv2 page in Venus OS v3.85.
- Bump the add-on version to `2.0.3`.

## 2.0.2

- Make the Home Assistant sidebar open Venus with the smoother web app download path, so it should stop acting like every click is its first day on the job.
- Keep the live Venus data connection local while allowing the static screen bundle to load from Victron's servers when needed.
- Bump the add-on version to `2.0.2`.

## 2.0.1

- Rename the Home Assistant sidebar entry to `Victron VenusOS`.
- Bump the add-on version to `2.0.1`.

## 2.0

- Fix Home Assistant changelog support by shipping `CHANGELOG.md` with the add-on.
- Require users to select a serial device in `Configuration` before startup and Web UI access.
- Add placeholder light and dark branding assets for the add-on card.
