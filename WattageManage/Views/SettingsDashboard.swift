import SwiftUI

struct SettingsDashboard: View {
    @EnvironmentObject private var history: LocalHistoryStore
    @Environment(\.dismiss) private var dismiss
    @Binding var capacityMilliampHours: Double
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    if let error = history.storageErrorMessage {
                        WattageCard {
                            Label("History could not be saved", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(WattageStyle.amber)
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(WattageStyle.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    WattageCard {
                        Eyebrow(title: "Estimate calibration")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(Int(capacityMilliampHours).formatted())
                                .font(.system(size: 27, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(WattageStyle.ink)
                            Text("mAh assumed capacity")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(WattageStyle.muted)
                        }
                        Slider(value: $capacityMilliampHours, in: 2_500...6_000, step: 100)
                            .tint(WattageStyle.mint)
                            .accessibilityLabel("Assumed battery capacity")
                        Text("Your iPhone doesn’t provide its battery capacity to apps. This assumption and a nominal cell voltage are used only to estimate stored battery energy. Adjust it to see how the estimate changes.")
                            .font(.system(size: 12))
                            .foregroundStyle(WattageStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    WattageCard {
                        Eyebrow(title: "Privacy")
                        PrivacyLine(symbol: "iphone", title: "Local history", detail: "Charging sessions and speed-test results are stored on this device.")
                        Divider().overlay(WattageStyle.line)
                        PrivacyLine(symbol: "network", title: "Network tests", detail: "Tests use Cloudflare's public speed-test host. Cloudflare receives your IP address; Wattage does not operate a server or upload your saved history.")
                        Divider().overlay(WattageStyle.line)
                        PrivacyLine(symbol: "dot.radiowaves.left.and.right", title: "Discovery", detail: "Bluetooth and Local Network access are requested only when you start a scan.")
                        Divider().overlay(WattageStyle.line)
                        PrivacyLine(symbol: "chart.xyaxis.line", title: "No tracking", detail: "No Wattage account, advertising, or analytics SDK is included.")
                    }

                    WattageCard {
                        Eyebrow(title: "Platform notes")
                        Text("Charging samples are collected while the app is active. iOS may suspend the app, and Home Screen widgets refresh on the system’s schedule. Nearby discovery can only show devices that advertise services visible to iOS.")
                            .font(.system(size: 12))
                            .foregroundStyle(WattageStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(role: .destructive, action: { confirmingDelete = true }) {
                        Label("Delete all saved history", systemImage: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(WattageStyle.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done", action: { dismiss() }).foregroundStyle(WattageStyle.mint) }
            }
            .confirmationDialog("Delete all local history?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete history", role: .destructive) { history.deleteHistory() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes every saved charging session and speed test from this device.")
            }
        }
        .tint(WattageStyle.mint)
        .preferredColorScheme(.dark)
    }
}

private struct PrivacyLine: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WattageStyle.mint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(WattageStyle.ink)
                Text(detail).font(.system(size: 11)).foregroundStyle(WattageStyle.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
