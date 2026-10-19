import Foundation
import CoreBluetooth
import Network
import Combine

@MainActor
final class DeviceDiscoveryService: NSObject, ObservableObject {
    enum ScanState: Equatable {
        case idle
        case scanning
        case bluetoothOff
        case unavailable
    }

    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var state: ScanState = .idle

    private var central: CBCentralManager?
    private var shouldStartBluetoothScan = false
    private var bluetoothStopTask: Task<Void, Never>?
    private var browsers: [NWBrowser] = []
    private var networkStopTask: Task<Void, Never>?

    func scanBluetooth() {
        devices.removeAll { $0.kind == .bluetooth }
        shouldStartBluetoothScan = true
        state = .scanning
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else if central?.state == .poweredOn {
            beginBluetoothScan()
        }
    }

    func discoverNetworkDevices() {
        stopNetworkDiscovery()
        devices.removeAll { $0.kind == .network }
        state = .scanning
        let serviceTypes = ["_http._tcp", "_airplay._tcp", "_ipp._tcp", "_smb._tcp", "_ssh._tcp"]
        browsers = serviceTypes.map { serviceType in
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                let discovered = results.compactMap { result -> DiscoveredDevice? in
                    guard case let .service(name, type, domain, _) = result.endpoint else { return nil }
                    return DiscoveredDevice(
                        id: "\(name).\(type).\(domain)",
                        name: name,
                        detail: "\(Self.friendlyServiceName(type)) service",
                        kind: .network,
                        lastSeen: Date()
                    )
                }
                MainActor.assumeIsolated { self?.merge(discovered) }
            }
            browser.stateUpdateHandler = { [weak self] browserState in
                if case .failed = browserState {
                    MainActor.assumeIsolated { self?.state = .unavailable }
                }
            }
            browser.start(queue: .main)
            return browser
        }
        networkStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }
            self?.stopNetworkDiscovery()
        }
    }

    func stopAll() {
        shouldStartBluetoothScan = false
        central?.stopScan()
        bluetoothStopTask?.cancel()
        stopNetworkDiscovery()
        if state == .scanning { state = .idle }
    }

    private func beginBluetoothScan() {
        guard central?.state == .poweredOn else { return }
        shouldStartBluetoothScan = false
        let batteryService = CBUUID(string: "180F")
        for peripheral in central?.retrieveConnectedPeripherals(withServices: [batteryService]) ?? [] {
            prepareBatteryRead(for: peripheral)
        }
        central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        bluetoothStopTask?.cancel()
        bluetoothStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.central?.stopScan()
            if self?.browsers.isEmpty == true { self?.state = .idle }
        }
    }

    private func stopNetworkDiscovery() {
        networkStopTask?.cancel()
        networkStopTask = nil
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        if central?.isScanning != true { state = .idle }
    }

    private func merge(_ incoming: [DiscoveredDevice]) {
        var byID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        for device in incoming { byID[device.id] = device }
        devices = byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func friendlyServiceName(_ type: String) -> String {
        switch type {
        case "_airplay._tcp": "AirPlay"
        case "_ipp._tcp", "_printer._tcp": "Printer"
        case "_smb._tcp": "File sharing"
        case "_ssh._tcp": "SSH"
        default: "Web"
        }
    }
}

extension DeviceDiscoveryService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                if self.shouldStartBluetoothScan { self.beginBluetoothScan() }
            case .poweredOff:
                self.state = .bluetoothOff
            case .unauthorized, .unsupported:
                self.state = .unavailable
            default:
                break
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "Unknown device"
        let device = DiscoveredDevice(
            id: peripheral.identifier.uuidString,
            name: name,
            detail: "Bluetooth · signal \(RSSI) dBm",
            kind: .bluetooth,
            lastSeen: Date()
        )
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let hasBatteryService = advertisedServices.contains(CBUUID(string: "180F"))
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.merge([device])
            if hasBatteryService { self.prepareBatteryRead(for: peripheral) }
        }
    }

    private func prepareBatteryRead(for peripheral: CBPeripheral) {
        peripheral.delegate = self
        central?.connect(peripheral, options: nil)
    }
}

extension DeviceDiscoveryService: CBPeripheralDelegate {
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: "180F")])
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let battery = peripheral.services?.first(where: { $0.uuid == CBUUID(string: "180F") }) else { return }
        peripheral.discoverCharacteristics([CBUUID(string: "2A19")], for: battery)
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil,
              let level = service.characteristics?.first(where: { $0.uuid == CBUUID(string: "2A19") }) else { return }
        peripheral.readValue(for: level)
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == CBUUID(string: "2A19"),
              let byte = characteristic.value?.first else { return }
        let percent = min(Int(byte), 100)
        Task { @MainActor [weak self] in
            self?.updateBatteryLevel(percent, peripheralID: peripheral.identifier)
            self?.central?.cancelPeripheralConnection(peripheral)
        }
    }
}

private extension DeviceDiscoveryService {
    func updateBatteryLevel(_ percent: Int, peripheralID: UUID) {
        guard let index = devices.firstIndex(where: { $0.id == peripheralID.uuidString }) else { return }
        devices[index].batteryPercent = percent
        devices[index].detail = "Bluetooth · accessory battery"
    }
}
