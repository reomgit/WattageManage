import Foundation

enum ChargePowerEstimate {
    static let nominalCellVoltage = 3.85
    static let minimumUsefulChange = 2.0

    static func watts(from samples: [ChargeSample], capacityMilliampHours: Double) -> ClosedRange<Double>? {
        guard capacityMilliampHours > 0, samples.count >= 2 else { return nil }
        let newest = samples.last!
        guard let oldest = samples.dropLast().reversed().first(where: {
            newest.levelPercent - $0.levelPercent >= minimumUsefulChange &&
            newest.timestamp.timeIntervalSince($0.timestamp) >= 120
        }) else { return nil }

        let hours = newest.timestamp.timeIntervalSince(oldest.timestamp) / 3_600
        let levelGain = newest.levelPercent - oldest.levelPercent
        guard hours > 0, levelGain >= minimumUsefulChange else { return nil }

        let storedEnergyWattHours = (levelGain / 100) * (capacityMilliampHours / 1_000) * nominalCellVoltage
        let estimate = storedEnergyWattHours / hours
        guard estimate.isFinite, estimate > 0 else { return nil }

        // Capacity and voltage are assumptions, so show a deliberately broad interval.
        return (estimate * 0.75)...(estimate * 1.25)
    }

    static func percentPerHour(from samples: [ChargeSample]) -> Double? {
        guard samples.count >= 2, let first = samples.first, let last = samples.last else { return nil }
        let elapsed = last.timestamp.timeIntervalSince(first.timestamp) / 3_600
        guard elapsed > 0, last.levelPercent > first.levelPercent else { return nil }
        return (last.levelPercent - first.levelPercent) / elapsed
    }
}

struct ChargeSample: Codable, Identifiable, Equatable {
    var id = UUID()
    var timestamp: Date
    var levelPercent: Double
}

struct ChargeSession: Codable, Identifiable, Equatable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date?
    var startPercent: Double
    var endPercent: Double?
    var setupLabel: String
    var samples: [ChargeSample]

    var duration: TimeInterval {
        (endedAt ?? samples.last?.timestamp ?? startedAt).timeIntervalSince(startedAt)
    }

    var percentGain: Double {
        (endPercent ?? samples.last?.levelPercent ?? startPercent) - startPercent
    }

    var percentPerHour: Double? {
        ChargePowerEstimate.percentPerHour(from: samples)
    }
}

struct NetworkTestResult: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var downloadMbps: Double
    var uploadMbps: Double
    var latencyMilliseconds: Double
    var jitterMilliseconds: Double
    var connectionType: String
    var testHost: String
}

struct DiscoveredDevice: Identifiable, Equatable {
    var id: String
    var name: String
    var detail: String
    var kind: Kind
    var lastSeen: Date
    var batteryPercent: Int? = nil

    enum Kind: String {
        case bluetooth = "Bluetooth"
        case network = "Wi-Fi"
    }
}
