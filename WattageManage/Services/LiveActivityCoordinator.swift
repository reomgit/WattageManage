import ActivityKit
import Foundation
import UIKit

@MainActor
enum LiveActivityCoordinator {
    static func endAll() async {
        for activity in Activity<ChargeActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func update(isCharging: Bool, batteryPercent: Double, estimate: ClosedRange<Double>?, startedAt: Date?, latestNetworkResult: NetworkTestResult?) async {
        let activities = Activity<ChargeActivityAttributes>.activities
        if isCharging, ActivityAuthorizationInfo().areActivitiesEnabled {
            let state = ChargeActivityAttributes.ContentState(
                mode: "charging",
                batteryPercent: Int(batteryPercent.rounded()),
                estimateLowWatts: estimate?.lowerBound,
                estimateHighWatts: estimate?.upperBound,
                networkDownloadMbps: nil,
                networkTestAt: nil,
                updatedAt: Date()
            )
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(300))
            if let activity = activities.first {
                await activity.update(content)
            } else {
                let attributes = ChargeActivityAttributes(startedAt: startedAt ?? Date())
                _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
            }
        } else if let latestNetworkResult,
                  Date().timeIntervalSince(latestNetworkResult.date) < 8 * 60 * 60,
                  let activity = activities.first {
            let state = networkState(for: latestNetworkResult, batteryPercent: batteryPercent)
            let content = ActivityContent(state: state, staleDate: latestNetworkResult.date.addingTimeInterval(8 * 60 * 60))
            await activity.update(content)
        } else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .after(Date().addingTimeInterval(60)))
            }
        }
    }

    static func showNetworkResult(_ result: NetworkTestResult, batteryPercent: Double) async {
        guard UIDevice.current.batteryState != .charging,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = networkState(for: result, batteryPercent: batteryPercent)
        let content = ActivityContent(state: state, staleDate: result.date.addingTimeInterval(8 * 60 * 60))
        if let activity = Activity<ChargeActivityAttributes>.activities.first {
            await activity.update(content)
        } else {
            let attributes = ChargeActivityAttributes(startedAt: result.date)
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
    }

    private static func networkState(for result: NetworkTestResult, batteryPercent: Double) -> ChargeActivityAttributes.ContentState {
        ChargeActivityAttributes.ContentState(
            mode: "network",
            batteryPercent: Int(batteryPercent.rounded()),
            estimateLowWatts: nil,
            estimateHighWatts: nil,
            networkDownloadMbps: result.downloadMbps,
            networkTestAt: result.date,
            updatedAt: result.date
        )
    }
}
