import SwiftUI

struct DevicesDashboard: View {
    @EnvironmentObject private var discovery: DeviceDiscoveryService
    var showSettings: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(subtitle: "See what’s visible nearby", showSettings: showSettings)

                WattageCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(title: "Local network")
                            Text("Bonjour devices")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(WattageStyle.ink)
                        }
                        Spacer()
                        Button(action: discovery.discoverNetworkDevices) {
                            Label("Discover", systemImage: "dot.radiowaves.left.and.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(WattageStyle.background)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 10)
                                .background(WattageStyle.mint, in: Capsule())
                        }
                        .accessibilityHint("Search for printers, media receivers, file sharing, and web services")
                    }
                    Text("Finds devices that advertise common network services. This is not a complete list of every device on your Wi-Fi.")
                        .font(.system(size: 12))
                        .foregroundStyle(WattageStyle.muted)
                    DeviceResults(devices: discovery.devices.filter { $0.kind == .network }, symbol: "wifi")
                }

                WattageCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(title: "Bluetooth")
                            Text("Nearby accessories")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(WattageStyle.ink)
                        }
                        Spacer()
                        Button(action: discovery.scanBluetooth) {
                            Label("Scan", systemImage: "dot.radiowaves.up.forward")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(WattageStyle.background)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 10)
                                .background(WattageStyle.blue, in: Capsule())
                        }
                    }
                    Text("A short foreground scan shows Bluetooth Low Energy devices that are currently advertising. Names and battery data depend on what each accessory exposes.")
                        .font(.system(size: 12))
                        .foregroundStyle(WattageStyle.muted)
                    DeviceResults(devices: discovery.devices.filter { $0.kind == .bluetooth }, symbol: "wave.3.right")
                }

                if discovery.state == .bluetoothOff {
                    Label("Turn on Bluetooth to scan for accessories.", systemImage: "bluetooth")
                        .font(.system(size: 12))
                        .foregroundStyle(WattageStyle.amber)
                } else if discovery.state == .unavailable {
                    Label("Discovery is unavailable. Check Bluetooth and Local Network permissions in Settings.", systemImage: "hand.raised.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(WattageStyle.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(WattageStyle.background.ignoresSafeArea())
        .onDisappear { discovery.stopAll() }
    }
}

private struct DeviceResults: View {
    var devices: [DiscoveredDevice]
    var symbol: String

    var body: some View {
        if devices.isEmpty {
            HStack(spacing: 11) {
                Image(systemName: symbol).foregroundStyle(WattageStyle.muted)
                Text("No devices found yet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WattageStyle.muted)
            }
            .padding(.vertical, 9)
        } else {
            VStack(spacing: 0) {
                ForEach(devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WattageStyle.mint)
                            .frame(width: 34, height: 34)
                            .background(WattageStyle.cardElevated, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(device.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(WattageStyle.ink)
                                .lineLimit(1)
                            Text(device.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(WattageStyle.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            if let battery = device.batteryPercent {
                                Label("\(battery)%", systemImage: "battery.100percent")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(WattageStyle.mint)
                            }
                            Text(device.lastSeen, format: .dateTime.hour().minute())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(WattageStyle.muted)
                        }
                    }
                    .padding(.vertical, 9)
                    if device.id != devices.last?.id { Divider().overlay(WattageStyle.line) }
                }
            }
        }
    }
}
