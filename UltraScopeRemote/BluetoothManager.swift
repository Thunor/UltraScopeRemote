import Foundation
import CoreBluetooth

/// BLE transparent serial specification for the HC-08 (compatible with the HM-10).
private let serviceUUID = CBUUID(string: "180A")
private let charUUID = CBUUID(string: "2A57")

enum ConnectionState: Equatable {
    case poweredOff       // Bluetooth is off / unavailable
    case idle             // Ready, not yet scanning
    case scanning
    case connecting
    case connected
}

@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    @Published var state: ConnectionState = .poweredOff
    @Published var discovered: [CBPeripheral] = []
    @Published var connectedName: String?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else { return }
        // Don't rescan while connected/connecting, otherwise it would overwrite the .connected state (the connection hasn't actually dropped)
        guard state != .connected, state != .connecting else { return }
        discovered.removeAll()
        state = .scanning
        // Prefer filtering by service UUID; a few HC-08 modules don't include the service in their advertisement,
        // so if none are found you can switch to scanForPeripherals(withServices: nil / [serviceUUID]) to scan everything and filter by name.
        central.scanForPeripherals(withServices:  nil, options: nil)
    }

    func stopScan() {
        central.stopScan()
        if state == .scanning { state = .idle }
    }

    func connect(_ p: CBPeripheral) {
        central.stopScan()
        peripheral = p
        state = .connecting
        central.connect(p, options: nil)
    }

    func disconnect() {
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
        resetConnection()
    }

    /// Sends a single ASCII command string, e.g. "F" / "B" / "L" / "R" / "S".
    func send(_ command: String) {
        guard let p = peripheral, let ch = writeCharacteristic else { return }
        let data = Data(command.utf8)
        let type: CBCharacteristicWriteType =
            ch.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(data, for: ch, type: type)
    }

    private func resetConnection() {
        peripheral = nil
        writeCharacteristic = nil
        connectedName = nil
        state = central?.state == .poweredOn ? .idle : .poweredOff
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                if state == .poweredOff { state = .idle }
            default:
                state = .poweredOff
                discovered.removeAll()
                peripheral = nil
                writeCharacteristic = nil
                connectedName = nil
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        Task { @MainActor in
            if !discovered.contains(where: { $0.identifier == peripheral.identifier }) {
                discovered.append(peripheral)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            let deviceName = peripheral.name ?? "Arduino"
            self.connectedName = deviceName
            print("Connected to device: \(deviceName) (UUID: \(peripheral.identifier))")
            // Update state to show we're connected but still discovering services
            self.state = .connecting
            peripheral.delegate = self
            peripheral.discoverServices([serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in resetConnection() }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in resetConnection() }
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            Task { @MainActor in
                print("Failed to discover services: \(error!.localizedDescription)")
                resetConnection()
            }
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            Task { @MainActor in
                print("No services found on peripheral")
                resetConnection()
            }
            return
        }
        
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([charUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            Task { @MainActor in
                print("Failed to discover characteristics: \(error!.localizedDescription)")
                resetConnection()
            }
            return
        }
        
        guard let characteristics = service.characteristics, !characteristics.isEmpty else {
            Task { @MainActor in
                print("No characteristics found for service")
                resetConnection()
            }
            return
        }
        
        for ch in characteristics where ch.uuid == charUUID {
            Task { @MainActor in
                self.writeCharacteristic = ch
                self.state = .connected
            }
        }
    }
}
