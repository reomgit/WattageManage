import ActivityKit
import Foundation

nonisolated struct ChargeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mode: String
        var batteryPercent: Int
        var estimateLowWatts: Double?
        var estimateHighWatts: Double?
        var networkDownloadMbps: Double?
        var networkTestAt: Date?
        var updatedAt: Date
    }

    var startedAt: Date
}

struct WattageWidgetSnapshot: Codable {
    var batteryPercent: Int = 0
    var isCharging = false
    var estimateLowWatts: Double?
    var estimateHighWatts: Double?
    var observedAt = Date.distantPast
    var latestDownloadMbps: Double?
    var networkTestAt: Date?

    static let suiteName = "group.dev.reom.WattageManage"
    private static let storageKey = "wattage.glance-snapshot.v1"

    static func load() -> Self {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.suiteName)?.set(data, forKey: Self.storageKey)
    }

    static func clearSavedResults() {
        var snapshot = load()
        snapshot.latestDownloadMbps = nil
        snapshot.networkTestAt = nil
        snapshot.estimateLowWatts = nil
        snapshot.estimateHighWatts = nil
        snapshot.save()
    }
}
