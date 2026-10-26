import Foundation
import CoreBluetooth
import Observation

struct DiscoveredSensor: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssi: Int
}

/// Connects to any Bluetooth LE sensor that offers the standard Heart Rate service (0x180D)
/// and reads its battery through the standard Battery service (0x180F), when it has one.
/// It never talks to proprietary protocols, so a sensor that doesn't publish these standard
/// services simply won't show a battery level.
@Observable
final class SensorMonitor: NSObject {
    private(set) var bluetoothState: CBManagerState = .unknown
    private(set) var discovered: [DiscoveredSensor] = []
    private(set) var connectedName: String?
    private(set) var isScanning = false
    private(set) var batteryLevel: Int?
    private(set) var bpm: Int?

    var isConnected: Bool { connectedName != nil }

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripherals: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var active: CBPeripheral?
    @ObservationIgnored private var wantsScan = false
    @ObservationIgnored private var userDisconnected = false

    private let hrService = CBUUID(string: "180D")
    private let hrMeasurement = CBUUID(string: "2A37")
    private let batteryService = CBUUID(string: "180F")
    private let batteryCharacteristic = CBUUID(string: "2A19")
    private let lastDeviceKey = "lastSensorID"

    override init() {
        super.init()
        // Reconnect to the last sensor on launch. Bluetooth permission is only asked
        // once a sensor has been paired before.
        if UserDefaults.standard.string(forKey: lastDeviceKey) != nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    // MARK: Controls

    func startScanning() {
        wantsScan = true
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else if central?.state == .poweredOn {
            beginScan()
        }
    }

    func stopScanning() {
        wantsScan = false
        central?.stopScan()
        isScanning = false
    }

    func connect(_ sensor: DiscoveredSensor) {
        guard let peripheral = peripherals[sensor.id], let manager = central else { return }
        stopScanning()
        userDisconnected = false
        active = peripheral
        peripheral.delegate = self
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: lastDeviceKey)
        manager.connect(peripheral)
    }

    func disconnect() {
        userDisconnected = true
        UserDefaults.standard.removeObject(forKey: lastDeviceKey)
        if let peripheral = active { central?.cancelPeripheralConnection(peripheral) }
    }

    // MARK: Private

    private func beginScan() {
        discovered.removeAll()
        peripherals.removeAll()
        central?.scanForPeripherals(withServices: [hrService], options: nil)
        isScanning = true
    }

    private func reconnectLast() {
        guard active == nil, let manager = central,
              let idString = UserDefaults.standard.string(forKey: lastDeviceKey),
              let id = UUID(uuidString: idString),
              let peripheral = manager.retrievePeripherals(withIdentifiers: [id]).first else { return }
        userDisconnected = false
        active = peripheral
        peripheral.delegate = self
        manager.connect(peripheral)      // stays pending until the sensor is in range
    }
}

extension SensorMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        guard central.state == .poweredOn else { isScanning = false; return }
        if wantsScan { beginScan() }
        reconnectLast()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripherals[peripheral.identifier] = peripheral
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Heart rate sensor"
        let sensor = DiscoveredSensor(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let i = discovered.firstIndex(where: { $0.id == sensor.id }) {
            discovered[i] = sensor
        } else {
            discovered.append(sensor)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedName = peripheral.name ?? "Heart rate sensor"
        peripheral.delegate = self
        peripheral.discoverServices([hrService, batteryService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        active = nil
        connectedName = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedName = nil
        bpm = nil
        batteryLevel = nil
        if userDisconnected {
            active = nil
        } else {
            central.connect(peripheral)   // out of range; reconnect when it's back
        }
    }
}

extension SensorMonitor: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            if service.uuid == hrService {
                peripheral.discoverCharacteristics([hrMeasurement], for: service)
            } else if service.uuid == batteryService {
                peripheral.discoverCharacteristics([batteryCharacteristic], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == hrMeasurement {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == batteryCharacteristic {
                peripheral.readValue(for: characteristic)
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let first = data.first else { return }
        if characteristic.uuid == batteryCharacteristic {
            batteryLevel = min(Int(first), 100)
        } else if characteristic.uuid == hrMeasurement {
            let bytes = [UInt8](data)
            let wide = bytes[0] & 0x01 != 0
            guard bytes.count >= (wide ? 3 : 2) else { return }
            let value = wide ? Int(bytes[1]) | (Int(bytes[2]) << 8) : Int(bytes[1])
            bpm = value > 0 ? value : nil
        }
    }
}
