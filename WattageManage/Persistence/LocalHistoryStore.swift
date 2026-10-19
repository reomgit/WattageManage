import Foundation
import Combine
import WidgetKit

@MainActor
final class LocalHistoryStore: ObservableObject {
    @Published private(set) var chargeSessions: [ChargeSession] = []
    @Published private(set) var networkResults: [NetworkTestResult] = []
    @Published private(set) var storageErrorMessage: String?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wattage", isDirectory: true)
        self.fileURL = fileURL ?? directory.appendingPathComponent("history.json")
        load()
    }

    var activeSession: ChargeSession? {
        chargeSessions.first(where: { $0.endedAt == nil })
    }

    func beginSession(at date: Date, level: Double) {
        guard activeSession == nil else { return }
        let sample = ChargeSample(timestamp: date, levelPercent: level)
        chargeSessions.insert(
            ChargeSession(startedAt: date, endedAt: nil, startPercent: level, endPercent: nil, setupLabel: "", samples: [sample]),
            at: 0
        )
        persist()
    }

    func record(level: Double, at date: Date) {
        guard let index = chargeSessions.firstIndex(where: { $0.endedAt == nil }) else { return }
        guard date.timeIntervalSince(chargeSessions[index].samples.last?.timestamp ?? .distantPast) >= 55 else { return }
        chargeSessions[index].samples.append(ChargeSample(timestamp: date, levelPercent: level))
        persist()
    }

    func endSession(at date: Date, level: Double) {
        guard let index = chargeSessions.firstIndex(where: { $0.endedAt == nil }) else { return }
        if date.timeIntervalSince(chargeSessions[index].samples.last?.timestamp ?? .distantPast) >= 1 {
            chargeSessions[index].samples.append(ChargeSample(timestamp: date, levelPercent: level))
        }
        chargeSessions[index].endedAt = date
        chargeSessions[index].endPercent = level
        persist()
    }

    func labelMostRecentSession(_ label: String) {
        guard let index = chargeSessions.firstIndex(where: { $0.endedAt == nil }) ?? chargeSessions.indices.first else { return }
        chargeSessions[index].setupLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func addNetworkResult(_ result: NetworkTestResult) {
        networkResults.insert(result, at: 0)
        persist()
    }

    func deleteHistory() {
        chargeSessions.removeAll()
        networkResults.removeAll()
        persist()
        WattageWidgetSnapshot.clearSavedResults()
        WidgetCenter.shared.reloadAllTimelines()
        Task { await LiveActivityCoordinator.endAll() }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let archive = try decoder.decode(HistoryArchive.self, from: data)
            chargeSessions = archive.chargeSessions
            networkResults = archive.networkResults
        } catch {
            chargeSessions = []
            networkResults = []
            storageErrorMessage = "Saved history could not be read: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let archive = HistoryArchive(chargeSessions: chargeSessions, networkResults: networkResults)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(archive).write(to: fileURL, options: .atomic)
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = error.localizedDescription
            print("Unable to save local Wattage history: \(error.localizedDescription)")
        }
    }
}

private struct HistoryArchive: Codable {
    var chargeSessions: [ChargeSession]
    var networkResults: [NetworkTestResult]
}
