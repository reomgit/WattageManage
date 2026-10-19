import SwiftUI
import Charts

struct ChargeDashboard: View {
    @EnvironmentObject private var charging: ChargingMonitor
    @EnvironmentObject private var history: LocalHistoryStore
    var capacityMilliampHours: Double
    var showSettings: () -> Void
    @State private var showingSetup = false

    private var watts: ClosedRange<Double>? { charging.estimate(capacityMilliampHours: capacityMilliampHours) }
    private var latestSamples: [ChargeSample] { Array(charging.activeSamples.suffix(20)) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(subtitle: "Charging, made clearer", showSettings: showSettings)

                ChargePowerCard(
                    level: charging.batteryPercent,
                    isCharging: charging.isCharging,
                    isPluggedIn: charging.isPluggedIn,
                    estimate: watts,
                    sampleDate: charging.lastObservedAt,
                    setupLabel: charging.latestSession?.setupLabel ?? "",
                    canEditSetup: charging.isCharging || charging.latestSession != nil
                ) { showingSetup = true }

                if charging.isCharging, let rate = ChargePowerEstimate.percentPerHour(from: latestSamples) {
                    WattageCard {
                        Eyebrow(title: "Observed charge rate")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(rate, format: .number.precision(.fractionLength(0...1)))
                                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(WattageStyle.ink)
                            Text("% / hour")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(WattageStyle.muted)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(WattageStyle.mint)
                        }
                        Text("Calculated from battery-level changes while Wattage is open.")
                            .font(.system(size: 12))
                            .foregroundStyle(WattageStyle.muted)
                    }
                }

                if latestSamples.count > 1 {
                    ChargeTrendCard(samples: latestSamples)
                } else if charging.isCharging {
                    WattageCard {
                        Eyebrow(title: "Charge trend")
                        Text("Gathering a useful trend")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(WattageStyle.ink)
                        Text("Battery level updates arrive gradually. The watt estimate appears after at least a 2% increase across two minutes or more.")
                            .font(.system(size: 13))
                            .foregroundStyle(WattageStyle.muted)
                    }
                }

                HStack(spacing: 12) {
                    SummaryTile(title: "Sessions", value: "\(history.chargeSessions.count)", symbol: "bolt.circle")
                    SummaryTile(title: "Last charge", value: history.chargeSessions.first.map { $0.percentGain.formatted(.number.precision(.fractionLength(0))) + "%" } ?? "—", symbol: "chart.line.uptrend.xyaxis")
                }
                Text("Battery percentage and charge state come from iOS. Wattage is an estimate of stored battery energy, not electrical power measured at the charger.")
                    .font(.system(size: 11))
                    .foregroundStyle(WattageStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(WattageStyle.background.ignoresSafeArea())
        .sheet(isPresented: $showingSetup) {
            SessionLabelSheet(initialValue: charging.latestSession?.setupLabel ?? "") { charging.setSetupLabel($0) }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct ChargePowerCard: View {
    var level: Double?
    var isCharging: Bool
    var isPluggedIn: Bool
    var estimate: ClosedRange<Double>?
    var sampleDate: Date?
    var setupLabel: String
    var canEditSetup: Bool
    var editSetup: () -> Void

    private var status: String {
        guard level != nil else { return "Battery data unavailable" }
        if isCharging { return "Charging now" }
        if isPluggedIn { return "Connected · charge complete" }
        return "Not charging"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(status, systemImage: isCharging ? "bolt.fill" : "battery.100percent")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCharging ? WattageStyle.mint : WattageStyle.muted)
                Spacer()
                if isCharging {
                    Circle().fill(WattageStyle.mint).frame(width: 7, height: 7)
                    Text("MONITORING")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(WattageStyle.mint)
                }
            }

            HStack(spacing: 18) {
                BatteryGauge(level: level, isCharging: isCharging)
                    .frame(width: 102, height: 102)
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(title: estimate == nil ? "Power estimate" : "Battery-side estimate")
                    if let estimate {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("~\(estimate.lowerBound.formatted(.number.precision(.fractionLength(1))))–\(estimate.upperBound.formatted(.number.precision(.fractionLength(1))))")
                                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(WattageStyle.ink)
                                .minimumScaleFactor(0.68)
                                .lineLimit(1)
                            Text("W")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(WattageStyle.mint)
                        }
                        Text("Approximate stored energy")
                            .font(.system(size: 12))
                            .foregroundStyle(WattageStyle.muted)
                    } else {
                        Text(isCharging ? "Building estimate" : "— W")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(WattageStyle.ink)
                        Text(isCharging ? "Waiting for battery-level change" : "Connect power to begin")
                            .font(.system(size: 12))
                            .foregroundStyle(WattageStyle.muted)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                Text("Approximation from battery-level change and a capacity assumption. Not a charger measurement.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11))
            .foregroundStyle(WattageStyle.muted)

            if canEditSetup {
                Button(action: editSetup) {
                    HStack(spacing: 7) {
                        Image(systemName: "cable.connector")
                        Text(setupLabel.isEmpty ? (isCharging ? "Label this charger & cable" : "Label last charging setup") : setupLabel)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "pencil")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WattageStyle.ink.opacity(0.86))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(WattageStyle.cardElevated, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .accessibilityHint("Add a label to this setup to compare observed charge rates in history")
            } else {
                Label("Setup labels are available during or after a charging session", systemImage: "cable.connector")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WattageStyle.muted)
            }

            if let sampleDate {
                Text("Last observed \(sampleDate.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WattageStyle.muted)
            }
        }
        .padding(19)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [WattageStyle.cardElevated, WattageStyle.card], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    Circle().fill(WattageStyle.blue.opacity(0.14)).frame(width: 160, height: 160).blur(radius: 48).offset(x: 34, y: -50)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(WattageStyle.line, lineWidth: 1))
    }
}

private struct BatteryGauge: View {
    var level: Double?
    var isCharging: Bool
    private var value: Double { min(max((level ?? 0) / 100, 0), 1) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.07), lineWidth: 8)
            Circle()
                .trim(from: 0, to: value)
                .stroke(LinearGradient(colors: [WattageStyle.blue, WattageStyle.mint], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.7), value: value)
            VStack(spacing: 1) {
                Text(level.map { Int($0.rounded()).formatted() } ?? "—")
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WattageStyle.ink)
                HStack(spacing: 2) {
                    if isCharging { Image(systemName: "bolt.fill") }
                    Text(level == nil ? "LEVEL" : "%")
                }
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(isCharging ? WattageStyle.mint : WattageStyle.muted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery level")
        .accessibilityValue(level.map { "\(Int($0.rounded())) percent" } ?? "Unavailable")
    }
}

private struct ChargeTrendCard: View {
    var samples: [ChargeSample]

    var body: some View {
        WattageCard {
            HStack {
                Eyebrow(title: "Battery trend")
                Spacer()
                Text("\(samples.count) samples")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WattageStyle.muted)
            }
            Chart(samples) { sample in
                AreaMark(x: .value("Time", sample.timestamp), y: .value("Level", sample.levelPercent))
                    .foregroundStyle(LinearGradient(colors: [WattageStyle.mint.opacity(0.25), WattageStyle.mint.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Time", sample.timestamp), y: .value("Level", sample.levelPercent))
                    .foregroundStyle(WattageStyle.mint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .chartYScale(domain: max(0, (samples.map(\.levelPercent).min() ?? 0) - 2)...min(100, (samples.map(\.levelPercent).max() ?? 100) + 2))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 112)
            Text("One-minute sample cadence while the app is visible")
                .font(.system(size: 11))
                .foregroundStyle(WattageStyle.muted)
        }
    }
}

struct SummaryTile: View {
    var title: String
    var value: String
    var symbol: String

    var body: some View {
        WattageCard {
            Image(systemName: symbol).foregroundStyle(WattageStyle.blue)
            Eyebrow(title: title)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(WattageStyle.ink)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SessionLabelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    var save: (String) -> Void

    init(initialValue: String, save: @escaping (String) -> Void) {
        _label = State(initialValue: initialValue)
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Compare this setup")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(WattageStyle.ink)
            Text("Add a charger or cable label to this charging session. You can compare observed charge rates later.")
                .font(.system(size: 14))
                .foregroundStyle(WattageStyle.muted)
            TextField("e.g. 20 W USB-C + braided cable", text: $label)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Charger and cable label")
            Button("Save label") {
                save(label)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(WattageStyle.background.ignoresSafeArea())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(WattageStyle.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WattageStyle.mint.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
