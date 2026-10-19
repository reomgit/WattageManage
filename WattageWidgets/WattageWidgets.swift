import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WattageWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChargeSnapshotWidget()
        ChargeSessionLiveActivity()
    }
}

private struct ChargeWidgetEntry: TimelineEntry {
    var date: Date
    var snapshot: WattageWidgetSnapshot
}

private struct ChargeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargeWidgetEntry {
        ChargeWidgetEntry(date: Date(), snapshot: WattageWidgetSnapshot(batteryPercent: 68, isCharging: true, estimateLowWatts: 5.2, estimateHighWatts: 8.7, observedAt: Date(), latestDownloadMbps: 184.2, networkTestAt: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargeWidgetEntry) -> Void) {
        completion(ChargeWidgetEntry(date: Date(), snapshot: WattageWidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargeWidgetEntry>) -> Void) {
        let now = Date()
        let entry = ChargeWidgetEntry(date: now, snapshot: WattageWidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

private struct ChargeSnapshotWidget: Widget {
    let kind = "WattageChargeSnapshot"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargeWidgetProvider()) { entry in
            ChargeSnapshotWidgetView(snapshot: entry.snapshot)
                .containerBackground(WattageWidgetStyle.background, for: .widget)
        }
        .configurationDisplayName("Wattage")
        .description("Last observed charge estimate or network speed test.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ChargeSnapshotWidgetView: View {
    var snapshot: WattageWidgetSnapshot
    @Environment(\.widgetFamily) private var family
    private var timestamp: Date { snapshot.isCharging ? snapshot.observedAt : (snapshot.networkTestAt ?? snapshot.observedAt) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: snapshot.isCharging ? "bolt.fill" : "bolt.circle.fill")
                    .foregroundStyle(WattageWidgetStyle.mint)
                Text("WATTAGE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(WattageWidgetStyle.muted)
                Spacer(minLength: 0)
                if timestamp > .distantPast {
                    HStack(spacing: 2) {
                        Text(snapshot.isCharging ? "Updated" : "Tested")
                        Text(timestamp, style: .relative)
                        Text("ago")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WattageWidgetStyle.muted)
                }
            }

            if snapshot.isCharging {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(snapshot.batteryPercent)%")
                        .font(.system(size: family == .systemSmall ? 29 : 36, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(WattageWidgetStyle.ink)
                    if let low = snapshot.estimateLowWatts, let high = snapshot.estimateHighWatts {
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("~\(low.formatted(.number.precision(.fractionLength(1))))–\(high.formatted(.number.precision(.fractionLength(1)))) W")
                                .font(.system(size: family == .systemSmall ? 12 : 16, weight: .bold, design: .rounded))
                                .foregroundStyle(WattageWidgetStyle.mint)
                            Text("stored power estimate")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(WattageWidgetStyle.muted)
                        }
                    }
                }
                ProgressView(value: Double(snapshot.batteryPercent), total: 100)
                    .tint(WattageWidgetStyle.mint)
                Text("Battery estimate · last observed")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WattageWidgetStyle.muted)
            } else if let speed = snapshot.latestDownloadMbps {
                Text(speed, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 31, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WattageWidgetStyle.ink)
                Text("Mbps download · last test")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WattageWidgetStyle.muted)
            } else {
                Text("Open Wattage")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(WattageWidgetStyle.ink)
                Text("Last observed charge and network results appear here.")
                    .font(.system(size: 10))
                    .foregroundStyle(WattageWidgetStyle.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

private struct ChargeSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargeActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(WattageWidgetStyle.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.mode == "charging" ? "Charging · \(context.state.batteryPercent)%" : "Latest network test")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(WattageWidgetStyle.ink)
                    if context.state.mode == "network", let download = context.state.networkDownloadMbps {
                        Text("\(download.formatted(.number.precision(.fractionLength(1)))) Mbps download")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WattageWidgetStyle.mint)
                    } else if let low = context.state.estimateLowWatts, let high = context.state.estimateHighWatts {
                        Text("~\(low.formatted(.number.precision(.fractionLength(1))))–\(high.formatted(.number.precision(.fractionLength(1)))) W battery-side estimate")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WattageWidgetStyle.muted)
                    } else {
                        Text("Waiting for a measurable battery change")
                            .font(.system(size: 11))
                            .foregroundStyle(WattageWidgetStyle.muted)
                    }
                    Text(context.state.mode == "network" ? "Tested \(context.state.updatedAt, style: .relative) ago" : "Updated \(context.state.updatedAt, style: .relative) ago")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WattageWidgetStyle.muted)
                }
                Spacer()
                Text("\(context.state.batteryPercent)%")
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WattageWidgetStyle.ink)
            }
            .padding(16)
            .activityBackgroundTint(WattageWidgetStyle.background)
            .activitySystemActionForegroundColor(WattageWidgetStyle.mint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.mode == "charging" {
                        Label("\(context.state.batteryPercent)%", systemImage: "bolt.fill")
                            .foregroundStyle(WattageWidgetStyle.mint)
                    } else {
                        Image(systemName: "wifi").foregroundStyle(WattageWidgetStyle.mint)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.mode == "network", let download = context.state.networkDownloadMbps {
                        Text("\(download.formatted(.number.precision(.fractionLength(1)))) Mbps")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(WattageWidgetStyle.ink)
                    } else if let low = context.state.estimateLowWatts, let high = context.state.estimateHighWatts {
                        Text("~\(low.formatted(.number.precision(.fractionLength(1))))–\(high.formatted(.number.precision(.fractionLength(1)))) W")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(WattageWidgetStyle.ink)
                    } else {
                        Text("Estimating")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WattageWidgetStyle.muted)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.mode == "charging" ? "Battery-side estimate" : "Latest test · not live throughput")
                        Spacer()
                        Text(context.state.mode == "network" ? "Tested \(context.state.updatedAt, style: .relative) ago" : "Updated \(context.state.updatedAt, style: .relative) ago")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WattageWidgetStyle.muted)
                }
            } compactLeading: {
                Image(systemName: context.state.mode == "charging" ? "bolt.fill" : "wifi").foregroundStyle(WattageWidgetStyle.mint)
            } compactTrailing: {
                if context.state.mode == "charging" {
                    Text("\(context.state.batteryPercent)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(WattageWidgetStyle.ink)
                } else if let download = context.state.networkDownloadMbps {
                    Text("\(Int(download.rounded()))")
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(WattageWidgetStyle.ink)
                }
            } minimal: {
                Image(systemName: context.state.mode == "charging" ? "bolt.fill" : "wifi").foregroundStyle(WattageWidgetStyle.mint)
            }
            .keylineTint(WattageWidgetStyle.mint)
        }
    }
}

private enum WattageWidgetStyle {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.075)
    static let ink = Color(red: 0.94, green: 0.96, blue: 1)
    static let muted = Color(red: 0.58, green: 0.63, blue: 0.72)
    static let mint = Color(red: 0.38, green: 0.91, blue: 0.77)
}
