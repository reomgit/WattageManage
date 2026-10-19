import Foundation
import UIKit
import Combine
import WidgetKit

@MainActor
final class ChargingMonitor: ObservableObject {
    @Published private(set) var batteryPercent: Double?
    @Published private(set) var batteryState: UIDevice.BatteryState = .unknown
    @Published private(set) var lastObservedAt: Date?

    private let history: LocalHistoryStore

    init(history: LocalHistoryStore) {
        self.history = history
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
    }

    var isCharging: Bool { batteryState == .charging }
    var isPluggedIn: Bool { batteryState == .charging || batteryState == .full }
    var latestSession: ChargeSession? { history.activeSession ?? history.chargeSessions.first }

    var activeSamples: [ChargeSample] {
        history.activeSession?.samples ?? history.chargeSessions.first?.samples ?? []
    }

    func estimate(capacityMilliampHours: Double) -> ClosedRange<Double>? {
        guard isCharging, let session = history.activeSession else { return nil }
        return ChargePowerEstimate.watts(from: session.samples, capacityMilliampHours: capacityMilliampHours)
    }

    func setSetupLabel(_ label: String) {
        history.labelMostRecentSession(label)
    }

    func refresh() {
        let device = UIDevice.current
        let level = Double(device.batteryLevel)
        let now = Date()
        batteryState = device.batteryState
        batteryPercent = level >= 0 ? level * 100 : nil
        lastObservedAt = now

        guard let batteryPercent else { return }
        if batteryState == .charging {
            if history.activeSession == nil { history.beginSession(at: now, level: batteryPercent) }
            history.record(level: batteryPercent, at: now)
        } else if batteryState == .full || batteryState == .unplugged {
            history.endSession(at: now, level: batteryPercent)
        }

        let estimate = batteryState == .charging
            ? ChargePowerEstimate.watts(from: history.activeSession?.samples ?? [], capacityMilliampHours: UserDefaults.standard.double(forKey: "assumedBatteryCapacityMilliampHours").nonzeroOr(4_000))
            : nil
        var snapshot = WattageWidgetSnapshot.load()
        let shouldReloadWidget = snapshot.batteryPercent != Int(batteryPercent.rounded()) || snapshot.isCharging != (batteryState == .charging)
        snapshot.batteryPercent = Int(batteryPercent.rounded())
        snapshot.isCharging = batteryState == .charging
        snapshot.estimateLowWatts = estimate?.lowerBound
        snapshot.estimateHighWatts = estimate?.upperBound
        snapshot.observedAt = now
        snapshot.save()
        if shouldReloadWidget { WidgetCenter.shared.reloadAllTimelines() }

        Task {
            await LiveActivityCoordinator.update(
                isCharging: batteryState == .charging,
                batteryPercent: batteryPercent,
                estimate: estimate,
                startedAt: history.activeSession?.startedAt,
                latestNetworkResult: history.networkResults.first
            )
        }
    }

    func sampleWhileVisible() async {
        while !Task.isCancelled {
            refresh()
            do { try await Task.sleep(for: .seconds(60)) }
            catch { return }
        }
    }
}

private extension Double {
    func nonzeroOr(_ fallback: Double) -> Double { self == 0 ? fallback : self }
}
