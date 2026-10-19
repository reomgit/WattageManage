# Wattage App Implementation Plan

> **For agentic workers:** Implement this plan task-by-task in the existing Xcode project. Steps use checkbox syntax for tracking.

**Goal:** Replace the starter screen with an open-source, local-first charging and connectivity monitor for iPhone.

**Architecture:** Keep the current SwiftUI app target and synchronized source folder. Add focused observable services for battery sampling, local history, network testing, and device discovery; compose these into four navigation destinations. Add a WidgetKit extension for glanceable state if target configuration permits it.

**Tech Stack:** Swift 5, SwiftUI, UIKit battery state, URLSession, Network/Bonjour, CoreBluetooth, ActivityKit, WidgetKit, App Intents, Codable local persistence.

## Global Constraints

- Preserve the existing iOS 27.0 deployment target and project identity.
- No private APIs, account backend, advertising, or analytics.
- Never label an estimate as a direct electrical measurement.
- Network tests run only after a user action and disclose the remote test host.
- Device scans run only on demand and show platform permission/visibility limits.
- Local histories remain on device and can be deleted by the user.
- Do not claim continuous background sampling or immediate widget refresh.

---

### Task 1: App foundation and local models

**Files:** `WattageManage/ContentView.swift`, `WattageManage/WattageManageApp.swift`, new model and persistence files beneath `WattageManage/`.

- [x] Replace the starter screen with a four-destination app shell and shared visual tokens.
- [x] Define identifiable Codable models for charge samples, charge sessions, and network results.
- [x] Add a small local store that loads, saves, and deletes histories from Application Support.
- [x] Keep production initial state empty; the preview uses the same empty store and does not seed readings.

### Task 2: Charging monitoring and history

**Files:** New battery monitor, estimator, charge dashboard, setup sheet, and session history views in `WattageManage/`.

- [x] Enable `UIDevice` battery monitoring and observe level/state notifications.
- [x] Record timestamped samples while foregrounded and close sessions when charging stops or the app detects a disconnect.
- [x] Compute charge rate from samples; compute estimated stored-battery watts only after sufficient level change and capacity configuration.
- [x] Show estimate range/assumptions, charging state, sample freshness, session duration, and charge progress.
- [x] Allow charger/cable labels and compare historical charge rates by label.

### Task 3: User-requested network tests

**Files:** New network test service, result model/persistence integration, and network view in `WattageManage/`.

- [x] Run latency samples and report median latency plus jitter as variation between samples.
- [x] Measure download and upload throughput through a documented external speed-test host.
- [x] Add progress, cancellation, failure, cellular/Wi-Fi label when available, and a clear remote-host disclosure.
- [x] Save completed results locally and display a history trend.

### Task 4: On-demand device discovery

**Files:** New Bluetooth and Bonjour discovery services, device view, and generated Info.plist permission settings.

- [x] Scan BLE peripherals in the foreground only after the user taps Scan.
- [x] Browse a bounded list of common Bonjour services after the user taps Discover on Wi-Fi.
- [x] Add accurate Bluetooth, Local Network, and Bonjour usage descriptions.
- [x] Merge duplicate observations, label unknown peripherals honestly, and stop scans on navigation/timeout.
- [x] Display accessory battery only if a public API or advertised Battery Service provides a real value.

### Task 5: Lock Screen, Dynamic Island, widget, and Shortcuts

**Files:** Widget extension source and project target settings, ActivityKit model/controller, App Intents source, and shared activity/widget views.

- [x] Add a charge-session Live Activity with last observed charge state, estimated value when available, and sample age.
- [x] End the activity when charging ends and handle the system's Live Activity time limit.
- [x] Add a small/medium Home Screen widget with last-known charge or latest network result and freshness label.
- [x] Add App Shortcuts to open Charge and start a network test; foreground the app for work needing live sensors or visible progress.
- [x] Verify no widget/activity says it is receiving live measurements when the app is suspended.

### Task 6: Open-source release and finishing pass

**Files:** `README.md`, `LICENSE`, in-app settings/privacy views, app project settings, and affected UI source.

- [x] Add MIT terms and build/run instructions.
- [x] Document estimates, iOS background behavior, discovery visibility, and the external speed-test host.
- [x] Add local history deletion and permission guidance.
- [x] Build the app and extension with the existing Xcode scheme and resolve compiler diagnostics.
- [x] Inspect the final diff and confirm no credentials, analytics packages, or generated readings entered production code.
