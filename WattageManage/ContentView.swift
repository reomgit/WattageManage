import SwiftUI

private enum WattageTab: Hashable {
    case charge
    case network
    case devices
    case history
}

struct ContentView: View {
    @StateObject private var history: LocalHistoryStore
    @StateObject private var charging: ChargingMonitor
    @StateObject private var network: NetworkSpeedTestService
    @StateObject private var discovery = DeviceDiscoveryService()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false
    @State private var selectedTab: WattageTab = .charge
    @AppStorage("assumedBatteryCapacityMilliampHours") private var batteryCapacity = 4_000.0

    init() {
        let history = LocalHistoryStore()
        _history = StateObject(wrappedValue: history)
        _charging = StateObject(wrappedValue: ChargingMonitor(history: history))
        _network = StateObject(wrappedValue: NetworkSpeedTestService(history: history))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChargeDashboard(capacityMilliampHours: batteryCapacity, showSettings: { showingSettings = true })
                .tabItem { Label("Charge", systemImage: "bolt.fill") }
                .tag(WattageTab.charge)

            NetworkDashboard(showSettings: { showingSettings = true })
                .tabItem { Label("Network", systemImage: "dot.radiowaves.left.and.right") }
                .tag(WattageTab.network)

            DevicesDashboard(showSettings: { showingSettings = true })
                .tabItem { Label("Devices", systemImage: "dot.radiowaves.up.forward") }
                .tag(WattageTab.devices)

            HistoryDashboard(showSettings: { showingSettings = true })
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(WattageTab.history)
        }
        .tint(WattageStyle.mint)
        .preferredColorScheme(.dark)
        .environmentObject(history)
        .environmentObject(charging)
        .environmentObject(network)
        .environmentObject(discovery)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await charging.sampleWhileVisible()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                charging.refresh()
                handleShortcutRequest()
            }
            else { discovery.stopAll() }
        }
        .onAppear(perform: handleShortcutRequest)
        .sheet(isPresented: $showingSettings) {
            SettingsDashboard(capacityMilliampHours: $batteryCapacity)
                .environmentObject(history)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func handleShortcutRequest() {
        if UserDefaults.standard.bool(forKey: "wattage.startSpeedTestFromShortcut") {
            UserDefaults.standard.set(false, forKey: "wattage.startSpeedTestFromShortcut")
            selectedTab = .network
            network.start()
        } else if UserDefaults.standard.bool(forKey: "wattage.openChargeFromShortcut") {
            UserDefaults.standard.set(false, forKey: "wattage.openChargeFromShortcut")
            selectedTab = .charge
        }
    }
}

#Preview {
    ContentView()
}
