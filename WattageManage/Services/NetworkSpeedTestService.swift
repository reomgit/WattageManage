import Foundation
import Network
import Combine
import WidgetKit
import UIKit

@MainActor
final class NetworkSpeedTestService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case latency
        case download
        case upload
        case saving
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var pathDescription = "Checking connection"
    @Published private(set) var progress = 0.0
    @Published private(set) var isRunning = false

    private let history: LocalHistoryStore
    private let pathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "wattage.network-path")
    private var task: Task<Void, Never>?
    private let host = "speed.cloudflare.com"

    init(history: LocalHistoryStore) {
        self.history = history
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let description: String
            if path.usesInterfaceType(.wifi) { description = "Wi-Fi" }
            else if path.usesInterfaceType(.cellular) { description = "Cellular" }
            else if path.usesInterfaceType(.wiredEthernet) { description = "Ethernet" }
            else { description = path.status == .satisfied ? "Connected" : "Offline" }
            Task { @MainActor [weak self] in self?.pathDescription = description }
        }
        pathMonitor.start(queue: queue)
    }

    deinit {
        pathMonitor.cancel()
        task?.cancel()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        task = Task { [weak self] in
            guard let self else { return }
            await self.run()
            self.task = nil
            self.isRunning = false
        }
    }

    func cancel() {
        task?.cancel()
    }

    private func run() async {
        do {
            phase = .latency
            progress = 0.08
            let latency = try await measureLatency()
            try Task.checkCancellation()

            phase = .download
            progress = 0.34
            let download = try await measureDownload(bytes: 10_000_000)
            try Task.checkCancellation()

            phase = .upload
            progress = 0.68
            let upload = try await measureUpload(bytes: 2_000_000)
            try Task.checkCancellation()

            phase = .saving
            let result = NetworkTestResult(
                date: Date(),
                downloadMbps: download,
                uploadMbps: upload,
                latencyMilliseconds: latency.median,
                jitterMilliseconds: latency.jitter,
                connectionType: pathDescription,
                testHost: host
            )
            history.addNetworkResult(result)
            var snapshot = WattageWidgetSnapshot.load()
            snapshot.latestDownloadMbps = result.downloadMbps
            snapshot.networkTestAt = result.date
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
            await LiveActivityCoordinator.showNetworkResult(
                result,
                batteryPercent: UIDevice.current.batteryLevel >= 0 ? Double(UIDevice.current.batteryLevel) * 100 : 0
            )
            progress = 1
            phase = .idle
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func measureLatency() async throws -> (median: Double, jitter: Double) {
        var samples: [Double] = []
        for _ in 0..<5 {
            try Task.checkCancellation()
            let start = ContinuousClock.now
            let url = URL(string: "https://\(host)/__down?bytes=0&cache=\(UUID().uuidString)")!
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.httpMethod = "GET"
            let (_, response) = try await URLSession.shared.data(for: request)
            try check(response)
            samples.append(seconds(start.duration(to: .now)) * 1_000)
        }
        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        let differences = zip(samples, samples.dropFirst()).map { abs($1 - $0) }
        let jitter = differences.isEmpty ? 0 : differences.reduce(0, +) / Double(differences.count)
        return (median, jitter)
    }

    private func measureDownload(bytes: Int) async throws -> Double {
        let url = URL(string: "https://\(host)/__down?bytes=\(bytes)&cache=\(UUID().uuidString)")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = "GET"
        let start = ContinuousClock.now
        let (data, response) = try await URLSession.shared.data(for: request)
        let elapsed = seconds(start.duration(to: .now))
        try check(response)
        guard !data.isEmpty else { throw TestError.emptyResponse }
        return Double(data.count * 8) / elapsed / 1_000_000
    }

    private func measureUpload(bytes: Int) async throws -> Double {
        let url = URL(string: "https://\(host)/__up")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let payload = Data(repeating: 0x41, count: bytes)
        let start = ContinuousClock.now
        let (_, response) = try await URLSession.shared.upload(for: request, from: payload)
        let elapsed = seconds(start.duration(to: .now))
        try check(response)
        return Double(bytes * 8) / elapsed / 1_000_000
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TestError.badResponse
        }
    }
}

private enum TestError: LocalizedError {
    case emptyResponse
    case badResponse

    var errorDescription: String? {
        switch self {
        case .emptyResponse: "The speed-test server returned no download data."
        case .badResponse: "The speed-test server returned an unexpected response."
        }
    }
}
