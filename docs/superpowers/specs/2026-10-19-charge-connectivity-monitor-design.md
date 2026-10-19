# Wattage Design

## Goal

Build an open-source iPhone utility that makes charging behavior understandable and brings network testing and nearby-device visibility into one private, local-first app.

## Product shape

The app is called **Wattage** and has four primary areas: Charge, Network, Devices, and History. Charging is the landing screen and the primary feature. Settings are available from the main navigation.

The visual direction is a dark, OLED-friendly instrument panel with electric blue and mint accents, strong numeric hierarchy, restrained gradients, and readable explanatory labels. The interface adapts to Dynamic Type and VoiceOver.

## Charging estimate

Use `UIDevice` battery monitoring and state notifications to collect battery percentage and charging state while the app is running. Sample no more frequently than the platform reports useful battery changes. Store samples and completed sessions locally. A session can include a user-entered charger/cable label for comparison.

iOS does not expose electrical input watts or exact battery capacity. The app will show battery percentage and charge rate from observed samples. Estimated watts are explicitly labeled as an approximation, use a user-configurable battery-capacity assumption and nominal cell voltage, and are withheld until enough percentage change exists to make the calculation meaningful. The UI identifies the estimate's assumptions and sample time. It never presents generated or stale data as a live measurement.

Sampling is foreground-led. When iOS suspends the app, Wattage cannot promise continuous sampling. A Live Activity can retain the most recently observed state and its timestamp; it cannot create new battery measurements while the process is suspended. Home Screen widgets use WidgetKit timelines and can refresh later than requested.

## Network testing

Run download, upload, latency, and jitter measurements only after an explicit user action. Save completed runs locally with timestamp and connection type when available. Show the remote test host and explain that test traffic reaches that host. No test results are uploaded to a Wattage service, and no account, ad, or analytics SDK is included.

## Device discovery

Provide an on-demand Bluetooth Low Energy scan and Bonjour browsing for known service types. Ask for Bluetooth or Local Network permission only when the user starts the related scan. Explain that iOS and device advertising limit identification: results can be unnamed, incomplete, or unavailable, and this is not a complete inventory of every device on Wi-Fi. Show battery information only when a connected accessory exposes it through a public API or standard Battery Service; do not infer AirPods battery percentages.

## Data and platform architecture

Use native SwiftUI, ActivityKit, WidgetKit, CoreBluetooth, Network/Bonjour, and Foundation URLSession. Keep monitoring and networking behind focused service types. Persist sessions and speed-test history locally in an app-owned store. Keep external speed-test traffic separate from persisted app data. Avoid third-party packages and account infrastructure.

Add App Intents for starting a charging monitor and launching a speed test, with foreground execution where needed. Add a WidgetKit extension for a last-known charge/network snapshot and a Live Activity for an active charging session. Every glanceable surface includes a freshness timestamp or an explicit stale state.

## Open source and accessibility

Include an MIT license, a README with build instructions and capability limitations, and an in-app privacy/settings screen describing local storage, network test traffic, and permissions. Support Dynamic Type, VoiceOver labels, sufficient contrast, and reduced motion.

## Initial delivery boundaries

All four main sections will have working native interactions and truthful empty/error states. Charging samples and history, user-requested speed tests, permission-gated device discovery, and local data deletion are in scope. Live Activities, widgets, and App Intents are included where the existing Xcode target setup can support them without private APIs or an external service. The iOS deployment target remains the project's current iOS 27.0.
