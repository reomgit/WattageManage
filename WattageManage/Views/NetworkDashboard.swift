import SwiftUI
import Charts

struct NetworkDashboard: View {
    @EnvironmentObject private var history: LocalHistoryStore
    @EnvironmentObject private var network: NetworkSpeedTestService
    var showSettings: () -> Void

    private var latest: NetworkTestResult? { history.networkResults.first }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(subtitle: "A quick read on your connection", showSettings: showSettings)

                WattageCard {
                    HStack {
                        Eyebrow(title: "Connection")
                        Spacer()
                        Label(network.pathDescription, systemImage: "wifi")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WattageStyle.mint)
                    }
                    if let latest {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(latest.downloadMbps, format: .number.precision(.fractionLength(1)))
                                .font(.system(size: 49, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(WattageStyle.ink)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("Mbps")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(WattageStyle.muted)
                        }
                        Text("Latest download · \(latest.date.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 12))
                            .foregroundStyle(WattageStyle.muted)
                    } else {
                        Text("Ready when you are")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(WattageStyle.ink)
                        Text("Run an on-demand check of download, upload, latency, and jitter.")
                            .font(.system(size: 13))
                            .foregroundStyle(WattageStyle.muted)
                    }

                    NetworkMetrics(result: latest)

                    if network.isRunning {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(phaseDescription)
                                Spacer()
                                Button("Cancel", action: network.cancel)
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(WattageStyle.muted)
                            ProgressView(value: network.progress)
                                .tint(WattageStyle.mint)
                        }
                    } else {
                        Button(action: network.start) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Run speed test")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    if case .failed(let message) = network.phase {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(WattageStyle.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                WattageCard {
                    Eyebrow(title: "Test details")
                    Text("Wattage uses Cloudflare's speed-test host")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WattageStyle.ink)
                    Text("A run transfers up to 12 MB to measure throughput and sends five small latency requests. Cloudflare receives your IP address and may use anonymized test measurements in its shared performance database. Wattage stores results only on this device.")
                        .font(.system(size: 12))
                        .foregroundStyle(WattageStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Link(destination: URL(string: "https://speed.cloudflare.com/")!) {
                        Label("Cloudflare speed-test privacy", systemImage: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WattageStyle.blue)
                    }
                }

                if history.networkResults.count > 1 {
                    NetworkTrendCard(results: Array(history.networkResults.prefix(12).reversed()))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(WattageStyle.background.ignoresSafeArea())
    }

    private var phaseDescription: String {
        switch network.phase {
        case .latency: "Measuring latency"
        case .download: "Measuring download"
        case .upload: "Measuring upload"
        case .saving: "Saving result"
        case .idle, .failed: "Preparing test"
        }
    }
}

private struct NetworkMetrics: View {
    var result: NetworkTestResult?

    var body: some View {
        HStack(spacing: 12) {
            MetricValue(value: result.map { $0.uploadMbps.formatted(.number.precision(.fractionLength(1))) } ?? "—", unit: "Mbps", title: "Upload")
            MetricValue(value: result.map { $0.latencyMilliseconds.formatted(.number.precision(.fractionLength(0))) } ?? "—", unit: "ms", title: "Latency")
            MetricValue(value: result.map { $0.jitterMilliseconds.formatted(.number.precision(.fractionLength(1))) } ?? "—", unit: "ms", title: "Jitter")
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .contain)
    }
}

private struct NetworkTrendCard: View {
    var results: [NetworkTestResult]

    var body: some View {
        WattageCard {
            Eyebrow(title: "Download trend")
            Chart(results) { result in
                LineMark(x: .value("Date", result.date), y: .value("Download", result.downloadMbps))
                    .foregroundStyle(WattageStyle.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                PointMark(x: .value("Date", result.date), y: .value("Download", result.downloadMbps))
                    .foregroundStyle(WattageStyle.mint)
            }
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(WattageStyle.line)
                AxisValueLabel().foregroundStyle(WattageStyle.muted)
            } }
            .frame(height: 145)
            Text("Your saved results stay on this device.")
                .font(.system(size: 11))
                .foregroundStyle(WattageStyle.muted)
        }
    }
}
