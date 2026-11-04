# CarDash — iPad version, 4 November 2026

This directory contains the source and image assets for the version installed on the iPad 2 (iOS 9.3.6). It is kept separate from the repository's other CarDash variants because they share header names but do not have the same interfaces.

It includes automatic and manual trip controls, per-drive summaries based on the iPad's vehicle charging state, dashboard and Drive Mode layouts, radio/music switching, and the optional wheel animation. The per-drive summary uses GPS estimates; it does not directly detect the ignition. The wheel animation is off by default.

`build-on-ipad.sh` uses the existing on-device ARMv7 toolchain and SDK under `/var/mobile/h109-build` (or `BUILD_ROOT`). It compiles and signs `CarDash.build` without installing or replacing any app or settings. The image files in `assets/` belong at the root of the app bundle. The existing installed map and its local resources are intentionally not included in this snapshot; preserve them when updating the app. The repository's other services and the separate music and camera apps remain necessary for their respective features.

The `tests/` directory includes synthetic trip and power-transition tests. Real driving, charger transitions in the vehicle, and switching audio through the car Bluetooth still require verification on the device.
