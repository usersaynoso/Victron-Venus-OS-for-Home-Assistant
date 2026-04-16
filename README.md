# Victron Venus OS for Home Assistant

This repository is a Home Assistant add-on repository for `Venus OS Local`.

It exists so Home Assistant can accept this GitHub URL in `Settings > Add-ons > Add-on Store > Repositories` and install the add-on directly from the UI.

## Install from the Home Assistant UI

1. In Home Assistant, go to `Settings > Add-ons > Add-on Store`.
2. Open the menu in the top-right and choose `Repositories`.
3. Add:

```text
https://github.com/usersaynoso/Victron-Venus-OS-for-Home-Assistant
```

4. Find `Venus OS Local` in the add-on store.
5. Open it, set `serial_device`, and start it.

## Repository Layout

- [repository.yaml](repository.yaml) is the Home Assistant repository manifest.
- [venus_local](venus_local) contains the add-on itself.
- [venus_local/README.md](venus_local/README.md) contains the detailed add-on documentation.

## Local Install Alternative

If you prefer a local add-on instead of adding the GitHub repository, copy the contents of [venus_local](venus_local) into `/addons/local/venus_local/` on the Home Assistant host, then reload the local add-on store.
