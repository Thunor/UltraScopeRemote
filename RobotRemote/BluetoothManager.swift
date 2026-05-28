import Foundation
import CoreBluetooth

/// HC-08 (與 HM-10 相容) 的 BLE 透明序列規格。
private let serviceUUID = CBUUID(string: "FFE0")
private let charUUID = CBUUID(string: "FFE1")

enum ConnectionState: Equatable {
    case poweredOff       // 藍牙未開啟 / 不可用
    case idle             // 已就緒，尚未掃描
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
        discovered.removeAll()
        state = .scanning
        // 優先用 service UUID 過濾；少數 HC-08 廣播未含 service，
        // 若掃不到可改成 scanForPeripherals(withServices: nil / [serviceUUID]) 全掃後依名稱過濾。
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

    /// 送出單一 ASCII 指令字串，例如 "F" / "B" / "L" / "R" / "S"。
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
            self.connectedName = peripheral.name ?? "HC-08"
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
        for service in peripheral.services ?? [] where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([charUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for ch in service.characteristics ?? [] where ch.uuid == charUUID {
            Task { @MainActor in
                self.writeCharacteristic = ch
                self.state = .connected
            }
        }
    }
}
