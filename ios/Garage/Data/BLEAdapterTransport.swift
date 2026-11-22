@preconcurrency import CoreBluetooth
import Foundation
import GarageCore

/// Talks to an ELM327-style OBD-II adapter over Bluetooth LE.
///
/// These dongles expose a serial pipe as two BLE characteristics (usually
/// FFF1 notify and FFF2 write, or one FFE1 that does both). This class finds the
/// adapter, finds that pipe, and turns it into `send(command) -> reply`. Everything
/// above it (setup, polling, trouble codes) is `ELM327Source` in GarageCore.
///
/// Not testable without hardware. The logic that can be tested lives in GarageCore.
final class BLEAdapterTransport: NSObject, OBDTransport, @unchecked Sendable {
    private(set) var name: String

    // CoreBluetooth calls back on `queue`; every property below is only touched there.
    private let queue = DispatchQueue(label: "garage.ble")
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    private var stateWaiter: CheckedContinuation<Void, Error>?
    private var scanWaiter: CheckedContinuation<CBPeripheral, Error>?
    private var connectWaiter: CheckedContinuation<Void, Error>?
    private var discoverWaiter: CheckedContinuation<Void, Error>?
    private var replyWaiter: CheckedContinuation<String, Error>?
    private var buffer = Data()
    private var pendingServices = 0
    private var commandNumber = 0

    private static let lastAdapterKey = "obd.lastAdapter"
    /// Services these dongles commonly advertise. Used only to recognise them while scanning.
    private static let knownServices = [CBUUID(string: "FFF0"), CBUUID(string: "FFE0"), CBUUID(string: "18F0")]
    private static let nameHints = ["OBD", "ELM", "VLINK", "VGATE", "VEEPEAK", "CX", "KONNWEI", "ICAR"]
    private static let ignoredServices = [CBUUID(string: "1800"), CBUUID(string: "1801"), CBUUID(string: "180A")]

    private override init() {
        name = "Bluetooth adapter"
        super.init()
        central = CBCentralManager(delegate: self, queue: queue)
    }

    /// Finds the adapter, connects, and returns a ready line. Throws a message fit to show the user.
    static func open(scanTimeout: TimeInterval = 15) async throws -> BLEAdapterTransport {
        let transport = BLEAdapterTransport()
        do {
            try await transport.waitUntilPoweredOn()
            let found = try await transport.findAdapter(timeout: scanTimeout)
            try await transport.connect(to: found)
            return transport
        } catch {
            await transport.close()
            throw error
        }
    }

    // MARK: OBDTransport

    func send(_ command: String, timeout: Duration) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard let peripheral, let writeCharacteristic, replyWaiter == nil else {
                    continuation.resume(throwing: peripheral == nil ? OBDLinkError.notConnected : OBDLinkError.adapterError("The adapter is busy."))
                    return
                }
                buffer.removeAll()
                replyWaiter = continuation
                commandNumber += 1
                let number = commandNumber
                let data = Data((command + "\r").utf8)
                let type: CBCharacteristicWriteType = writeCharacteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                let chunk = max(20, peripheral.maximumWriteValueLength(for: type))
                var offset = 0
                while offset < data.count {
                    peripheral.writeValue(data.subdata(in: offset..<min(offset + chunk, data.count)), for: writeCharacteristic, type: type)
                    offset += chunk
                }
                let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
                queue.asyncAfter(deadline: .now() + seconds) { [weak self] in
                    // A timer from an earlier command must not cut short the one in flight now.
                    guard let self, commandNumber == number else { return }
                    finishReply(.failure(OBDLinkError.timeout))
                }
            }
        }
    }

    func close() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async { [self] in
                finishReply(.failure(OBDLinkError.notConnected))
                if let peripheral, central.state == .poweredOn { central.cancelPeripheralConnection(peripheral) }
                if central.isScanning { central.stopScan() }
                peripheral = nil
                writeCharacteristic = nil
                notifyCharacteristic = nil
                done.resume()
            }
        }
    }

    // MARK: Connecting

    private func waitUntilPoweredOn() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                if let error = stateError(central.state) {
                    if central.state == .unknown || central.state == .resetting {
                        stateWaiter = continuation   // the first callback usually arrives a moment later
                        queue.asyncAfter(deadline: .now() + 5) { [weak self] in
                            guard let self, let waiter = stateWaiter else { return }
                            stateWaiter = nil
                            waiter.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func stateError(_ state: CBManagerState) -> OBDLinkError? {
        switch state {
        case .poweredOn: nil
        case .poweredOff: .adapterError("Bluetooth is off. Turn it on in Control Center.")
        case .unauthorized: .adapterError("Garage isn't allowed to use Bluetooth. Turn it on in Settings > Garage.")
        case .unsupported: .adapterError("This device can't use Bluetooth LE.")
        default: .adapterError("Bluetooth isn't ready yet. Try again in a moment.")
        }
    }

    private func findAdapter(timeout: TimeInterval) async throws -> CBPeripheral {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CBPeripheral, Error>) in
            queue.async { [self] in
                // Last adapter first: no scan needed when it is still known to the phone.
                if let saved = UserDefaults.standard.string(forKey: Self.lastAdapterKey).flatMap(UUID.init(uuidString:)),
                   let known = central.retrievePeripherals(withIdentifiers: [saved]).first {
                    continuation.resume(returning: known)
                    return
                }
                scanWaiter = continuation
                central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
                queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                    guard let self, let waiter = scanWaiter else { return }
                    scanWaiter = nil
                    central.stopScan()
                    waiter.resume(throwing: OBDLinkError.adapterError("No adapter found. Plug it into the car's OBD port, turn the ignition on, and try again."))
                }
            }
        }
    }

    private func connect(to found: CBPeripheral) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                peripheral = found
                name = found.name ?? "Bluetooth adapter"
                found.delegate = self
                connectWaiter = continuation
                central.connect(found)
                queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                    guard let self, let waiter = connectWaiter else { return }
                    connectWaiter = nil
                    waiter.resume(throwing: OBDLinkError.adapterError("Couldn't connect to \(name). Is another app connected to it?"))
                }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                discoverWaiter = continuation
                found.discoverServices(nil)
                queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                    guard let self, let waiter = discoverWaiter else { return }
                    discoverWaiter = nil
                    waiter.resume(throwing: OBDLinkError.unsupported("\(name) doesn't look like an OBD-II adapter."))
                }
            }
        }
        UserDefaults.standard.set(found.identifier.uuidString, forKey: Self.lastAdapterKey)
    }

    private func finishReply(_ result: Result<String, Error>) {
        guard let waiter = replyWaiter else { return }
        replyWaiter = nil
        waiter.resume(with: result)
    }

    private func pickPipe(from service: CBService) -> (notify: CBCharacteristic, write: CBCharacteristic)? {
        guard let characteristics = service.characteristics else { return nil }
        let notify = characteristics.first { $0.properties.contains(.notify) || $0.properties.contains(.indicate) }
        let write = characteristics.first { $0.properties.contains(.writeWithoutResponse) || $0.properties.contains(.write) }
        if let notify, let write { return (notify, write) }
        return nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEAdapterTransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard let waiter = stateWaiter else {
            if central.state != .poweredOn { finishReply(.failure(OBDLinkError.notConnected)) }
            return
        }
        if central.state == .poweredOn {
            stateWaiter = nil
            waiter.resume()
        } else if let error = stateError(central.state), central.state != .unknown, central.state != .resetting {
            stateWaiter = nil
            waiter.resume(throwing: error)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard let waiter = scanWaiter else { return }
        let advertisedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let nameMatches = Self.nameHints.contains { advertisedName.uppercased().contains($0) }
        let serviceMatches = services.contains { Self.knownServices.contains($0) }
        guard nameMatches || serviceMatches else { return }
        scanWaiter = nil
        central.stopScan()
        waiter.resume(returning: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let waiter = connectWaiter else { return }
        connectWaiter = nil
        waiter.resume()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let waiter = connectWaiter else { return }
        connectWaiter = nil
        waiter.resume(throwing: OBDLinkError.adapterError("Couldn't connect to \(name)."))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        finishReply(.failure(OBDLinkError.notConnected))
    }
}

// MARK: - CBPeripheralDelegate

extension BLEAdapterTransport: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let services = (peripheral.services ?? []).filter { !Self.ignoredServices.contains($0.uuid) }
        guard error == nil, !services.isEmpty else {
            discoverWaiter?.resume(throwing: OBDLinkError.unsupported("\(name) doesn't look like an OBD-II adapter."))
            discoverWaiter = nil
            return
        }
        pendingServices = services.count
        for service in services { peripheral.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard discoverWaiter != nil else { return }
        if writeCharacteristic == nil, let pipe = pickPipe(from: service) {
            writeCharacteristic = pipe.write
            notifyCharacteristic = pipe.notify
            peripheral.setNotifyValue(true, for: pipe.notify)
            return   // resumes in didUpdateNotificationStateFor
        }
        pendingServices -= 1
        if pendingServices <= 0, writeCharacteristic == nil {
            discoverWaiter?.resume(throwing: OBDLinkError.unsupported("\(name) doesn't look like an OBD-II adapter."))
            discoverWaiter = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard let waiter = discoverWaiter else { return }
        discoverWaiter = nil
        if error == nil, characteristic.isNotifying {
            waiter.resume()
        } else {
            waiter.resume(throwing: OBDLinkError.unsupported("Couldn't listen to \(name)."))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value, replyWaiter != nil else { return }
        buffer.append(value)
        // An ELM327 ends every reply with ">" when it is ready for the next command.
        guard let end = buffer.firstIndex(of: UInt8(ascii: ">")) else { return }
        let text = String(decoding: buffer[..<end], as: UTF8.self)
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        buffer.removeAll()
        finishReply(.success(text))
    }
}
