import AppIntents

struct OpenChargeMonitorIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Charge Monitor"
    static var description = IntentDescription("Open Wattage to view battery level and the latest charging estimate.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "wattage.openChargeFromShortcut")
        return .result(dialog: "Opening Wattage charge monitor.")
    }
}

struct StartNetworkSpeedTestIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Network Speed Test"
    static var description = IntentDescription("Open Wattage and start a user-requested network speed test.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "wattage.startSpeedTestFromShortcut")
        return .result(dialog: "Opening Wattage to run a network speed test.")
    }
}

struct WattageShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenChargeMonitorIntent(),
            phrases: ["Open charging monitor in \(.applicationName)", "Show charging power in \(.applicationName)"],
            shortTitle: "Charge monitor",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: StartNetworkSpeedTestIntent(),
            phrases: ["Run a network speed test in \(.applicationName)"],
            shortTitle: "Speed test",
            systemImageName: "speedometer"
        )
    }
}
