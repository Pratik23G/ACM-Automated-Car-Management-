import Foundation
import CoreBluetooth
import Combine
import UserNotifications

/// Watches for a known Bluetooth device (the user's car) connecting/disconnecting.
/// When the paired device is found, it writes a drive start to SharedDefaults.
/// Works alongside — not instead of — the manual and motion-based triggers.
@MainActor
final class BluetoothTripTrigger: NSObject, ObservableObject {

    // MARK: - Published

    @Published var state:           CBManagerState = .unknown
    @Published var nearbyDevices:   [DiscoveredDevice] = []
    @Published var isScanning:      Bool = false

    // MARK: - Callbacks

    var onCarConnected:    (() -> Void)?
    var onCarDisconnected: (() -> Void)?

    // MARK: - State

    private var central:         CBCentralManager!
    private var pairedDeviceUUID: String?
    private var driveStartTime:   Date?
    private var scanTimer:        Timer?

    // MARK: - Init

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    // MARK: - Public API

    func configure(pairedDeviceUUID: String?) {
        self.pairedDeviceUUID = pairedDeviceUUID
    }

    /// Start a 15-second scan to discover nearby Bluetooth devices for pairing.
    func startDiscoveryScan() {
        guard state == .poweredOn else { return }
        nearbyDevices.removeAll()
        isScanning = true
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
            DispatchQueue.main.async { [weak self] in self?.stopDiscoveryScan() }
        }
    }

    func stopDiscoveryScan() {
        central.stopScan()
        isScanning = false
        scanTimer?.invalidate()
    }

    // MARK: - Internal

    private func handleDeviceAppeared(uuid: String, name: String?) {
        guard let paired = pairedDeviceUUID, uuid == paired else { return }
        if driveStartTime == nil {
            driveStartTime = Date()
            onCarConnected?()
        }
    }

    private func handleDeviceDisappeared(uuid: String) {
        guard let paired = pairedDeviceUUID, uuid == paired else { return }
        guard let start = driveStartTime else { return }
        let end = Date()
        driveStartTime = nil
        onCarDisconnected?()

        let duration = end.timeIntervalSince(start) / 60
        guard duration >= 2 else { return }  // ignore brief disconnects

        let pending = PendingAutoTrip(startedAt: start, endedAt: end, source: .bluetooth)
        SharedDefaults.pendingAutoTrip = pending

        let content = UNMutableNotificationContent()
        content.title = "🚗 Drive Detected via Bluetooth"
        content.body  = "Car disconnected after \(pending.durationFormatted). Save this trip?"
        content.sound = .default
        content.categoryIdentifier = "DRIVE_CONFIRM"
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "bt_\(pending.id.uuidString)",
                                  content: content,
                                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2,
                                                                              repeats: false))
        )
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothTripTrigger: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in self.state = central.state }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let uuid = peripheral.identifier.uuidString
        Task { @MainActor in
            // Deduplicate
            if !self.nearbyDevices.contains(where: { $0.uuid == uuid }) {
                self.nearbyDevices.append(DiscoveredDevice(uuid: uuid, name: name, rssi: RSSI.intValue))
                self.nearbyDevices.sort { ($0.rssi) > ($1.rssi) }
            }
            self.handleDeviceAppeared(uuid: uuid, name: name)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            self.handleDeviceDisappeared(uuid: peripheral.identifier.uuidString)
        }
    }
}

// MARK: - DiscoveredDevice

struct DiscoveredDevice: Identifiable, Equatable {
    let id   = UUID()
    let uuid: String
    let name: String?
    let rssi: Int

    var displayName: String { name ?? "Unknown Device (\(uuid.prefix(8)))" }
    var signalStrength: String {
        switch rssi {
        case -50...0:    return "Excellent"
        case -70 ..< -50: return "Good"
        case -90 ..< -70: return "Fair"
        default:          return "Weak"
        }
    }
}

