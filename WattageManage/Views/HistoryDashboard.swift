import SwiftUI
import Charts

struct HistoryDashboard: View {
    @EnvironmentObject private var history: LocalHistoryStore
    var showSettings: () -> Void

    private var comparisons: [SetupComparison] {
        let groups = Dictionary(grouping: history.chargeSessions.filter { !$0.setupLabel.isEmpty && $0.percentPerHour != nil }, by: \.setupLabel)
        return groups.map { label, sessions in
            SetupComparison(label: label, averagePercentPerHour: sessions.compactMap(\.percentPerHour).reduce(0, +) / Double(sessions.count), sessions: sessions.count)
        }.sorted { $0.averagePercentPerHour > $1.averagePercentPerHour }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(subtitle: "Your measurements, on this device", showSettings: showSettings)

                HStack(spacing: 12) {
                    SummaryTile(title: "Charge sessions", value: "\(history.chargeSessions.count)", symbol: "bolt.circle")
                    SummaryTile(title: "Speed tests", value: "\(history.networkResults.count)", symbol: "speedometer")
                }

                if !comparisons.isEmpty {
                    SetupComparisonCard(comparisons: comparisons)
                }

                SectionHeading(title: "Charging sessions", trailing: "Newest first")
                if history.chargeSessions.isEmpty {
                    WattageCard {
                        EmptyState(symbol: "bolt.circle", title: "No sessions yet", detail: "Charging sessions appear here after Wattage observes a charge while the app is open.")
                    }
                } else {
                    VStack(spacing: 11) {
                        ForEach(history.chargeSessions) { session in
                            ChargeSessionRow(session: session)
                        }
                    }
                }

                SectionHeading(title: "Speed tests", trailing: "Saved locally")
                if history.networkResults.isEmpty {
                    WattageCard {
                        EmptyState(symbol: "dot.radiowaves.left.and.right", title: "No tests yet", detail: "Run a network test to start building a local history.")
                    }
                } else {
                    VStack(spacing: 11) {
                        ForEach(history.networkResults) { result in
                            NetworkResultRow(result: result)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(WattageStyle.background.ignoresSafeArea())
    }
}

private struct SetupComparison: Identifiable {
    var id: String { label }
    var label: String
    var averagePercentPerHour: Double
    var sessions: Int
}

private struct SetupComparisonCard: View {
    var comparisons: [SetupComparison]

    var body: some View {
        WattageCard {
            Eyebrow(title: "Setup comparison")
            Text("Average observed charge rate")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WattageStyle.ink)
            Chart(comparisons) { item in
                BarMark(x: .value("Rate", item.averagePercentPerHour), y: .value("Setup", item.label))
                    .foregroundStyle(LinearGradient(colors: [WattageStyle.blue, WattageStyle.mint], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(5)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(item.averagePercentPerHour.formatted(.number.precision(.fractionLength(0))) )%/h")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WattageStyle.muted)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(WattageStyle.muted) } }
            .frame(height: CGFloat(max(1, comparisons.count) * 38))
            Text("Charge rates come from battery percentage changes, not a direct power reading.")
                .font(.system(size: 11))
                .foregroundStyle(WattageStyle.muted)
        }
    }
}

private struct ChargeSessionRow: View {
    var session: ChargeSession

    var body: some View {
        WattageCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.setupLabel.isEmpty ? "Charging session" : session.setupLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WattageStyle.ink)
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(WattageStyle.muted)
                }
                Spacer()
                Text(session.endedAt == nil ? "ACTIVE" : session.percentGain >= 0 ? "+\(Int(session.percentGain.rounded()))%" : "—")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(session.endedAt == nil ? WattageStyle.mint : WattageStyle.blue)
            }
            HStack(spacing: 16) {
                CompactMetric(label: "Duration", value: Duration.seconds(session.duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                if let rate = session.percentPerHour {
                    CompactMetric(label: "Observed", value: "\(rate.formatted(.number.precision(.fractionLength(0))) )%/h")
                }
                CompactMetric(label: "Samples", value: "\(session.samples.count)")
            }
        }
    }
}

private struct NetworkResultRow: View {
    var result: NetworkTestResult

    var body: some View {
        WattageCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WattageStyle.ink)
                    Text("\(result.connectionType) · \(result.testHost)")
                        .font(.system(size: 10))
                        .foregroundStyle(WattageStyle.muted)
                }
                Spacer()
                Text("\(result.downloadMbps.formatted(.number.precision(.fractionLength(1)))) ↓")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WattageStyle.mint)
            }
            HStack(spacing: 14) {
                CompactMetric(label: "Upload", value: "\(result.uploadMbps.formatted(.number.precision(.fractionLength(1)))) Mbps")
                CompactMetric(label: "Ping", value: "\(result.latencyMilliseconds.formatted(.number.precision(.fractionLength(0)))) ms")
                CompactMetric(label: "Jitter", value: "\(result.jitterMilliseconds.formatted(.number.precision(.fractionLength(1)))) ms")
            }
        }
    }
}

private struct CompactMetric: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(0.6).foregroundStyle(WattageStyle.muted)
            Text(value).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(WattageStyle.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
