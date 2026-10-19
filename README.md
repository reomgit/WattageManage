# Wattage

[![Build IPA](https://github.com/reomgit/WattageManage/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/reomgit/WattageManage/actions/workflows/build-ipa.yml)

Wattage is an open-source iPhone utility for understanding battery charging trends, testing internet performance, and discovering nearby devices that advertise services visible to iOS.

## Features

- Observe battery level and charge state while the app is active.
- Record local charging sessions and label a charger/cable setup.
- Estimate stored battery-side power from battery percentage change. The estimate is shown as a range and depends on a user-adjustable capacity assumption.
- Run a user-requested download, upload, latency, and jitter test.
- Browse common Bonjour service types on the local network and scan nearby Bluetooth LE advertisements.
- View local charging and speed-test history, compare labeled setups, and delete saved history.
- Show last-observed values in a Home Screen widget and charging Live Activity.
- Open charging or start a test with Siri Shortcuts / App Intents.

## Important limitations

iOS does not expose the electrical watts entering the iPhone or the exact battery capacity to third-party apps. Wattage estimates average energy stored in the battery from observed percentage changes, a nominal cell voltage, and the configured capacity assumption. It is not a charger or laboratory measurement. The charge-level API reports changes no more frequently than about once a minute, and Wattage samples while it is active; iOS may suspend it in the background. The Dynamic Island and widget therefore show the last observed value and its age, and widget refresh timing is controlled by iOS.

Network tests use Cloudflare's public speed-test host at `speed.cloudflare.com`. A test sends about 12 MB of measurement traffic and five small latency requests. Cloudflare receives the user's IP address and may use anonymized test measurements in its shared performance database. Wattage stores completed results only on device and does not upload them to a Wattage server. See [Cloudflare Speed Test](https://speed.cloudflare.com/) for its current privacy details.

Local-network discovery browses only common Bonjour service types. It will not find every Wi-Fi client. Bluetooth scanning sees nearby peripherals that advertise while Wattage is scanning. Device names, AirPods battery state, and accessory battery levels are available only when the accessory and public iOS APIs expose them; Wattage does not use private APIs or infer missing battery percentages.

The app contains no account service, ads, or analytics SDK. Histories are stored in the app's local Application Support directory and can be cleared in Settings. The glanceable widget snapshot is shared with the widget through an App Group container.

## Build

1. Open `WattageManage.xcodeproj` in Xcode 27 or later.
2. Select the `WattageManage` scheme and an iOS 27 simulator or device.
3. Set your Apple development team and register the App Group identifier `group.dev.reom.WattageManage` for device builds if your signing setup requires it.
4. Build and run. Battery level and Bluetooth discovery require a physical iPhone for meaningful results.

No third-party Swift packages are required.

## IPA downloads and CI/CD

[GitHub Actions](https://github.com/reomgit/WattageManage/actions) builds an unsigned iPhone IPA for each push to `main` and each pull request. Version tags publish the IPA and SHA-256 checksum to [GitHub Releases](https://github.com/reomgit/WattageManage/releases). Unsigned IPAs need re-signing before installation.

A separate manual **Signed IPA** workflow exports an IPA using Apple Distribution signing assets stored in repository secrets. See [CI/CD and signing setup](docs/ci-cd.md) for downloads, release tags, required profiles, and signing secrets.

## License

Wattage is distributed under the [MIT License](LICENSE).
