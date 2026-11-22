import Foundation
import GarageCore
import Observation

/// Holds the live connection to an OBD source and the newest value of each PID.
/// The gauge screen reads this; trip logging and CarPlay will read it too.
@MainActor
@Observable
final class OBDSession {
    private(set) var state: OBDConnectionState = .disconnected
    private(set) var latest: [OBDPID: OBDReading] = [:]

    private(set) var source: OBDDataSource
    private var task: Task<Void, Never>?

    /// Stored trouble codes from the latest read, such as ["P0456"].
    private(set) var troubleCodes: [String] = []
    /// False until the first read after connecting, so screens can tell "no codes" from "not read yet".
    private(set) var hasReadCodes = false
    /// Problems happening right now: hot coolant, or a trouble code the car is reporting.
    /// An alert leaves this list when its cause goes away. CarPlay shows each one once.
    private(set) var alerts: [DriveAlert] = []

    private var coolantHot = false
    private var codeTask: Task<Void, Never>?
    /// How often the connected car is asked for trouble codes.
    private static let codeInterval: Duration = .seconds(60)

    /// Called with every batch of readings, as they arrive. Trip recording listens here.
    var onReadings: (([OBDReading]) -> Void)?
    /// Called when the connection ends: stopped by the user, dropped, or failed.
    var onDisconnect: (() -> Void)?

    init(source: OBDDataSource) {
        self.source = source
    }

    var isActive: Bool { task != nil }

    /// Switches between the real adapter and the simulator. Stops any running connection first.
    func use(_ newSource: OBDDataSource) {
        if isActive { stop() }
        source = newSource
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, source] in
            for await event in source.events() {
                guard let self, !Task.isCancelled else { break }
                switch event {
                case .state(let state):
                    self.state = state
                    switch state {
                    case .connected: self.startCodePolling()
                    case .disconnected, .failed:
                        self.stopCodePolling()
                        self.onDisconnect?()
                    default: break
                    }
                case .readings(let readings):
                    for reading in readings { self.latest[reading.pid] = reading }
                    self.checkCoolant(in: readings)
                    self.onReadings?(readings)
                }
            }
        }
    }

    func stop() {
        onDisconnect?()
        stopCodePolling()
        task?.cancel()
        task = nil
        state = .disconnected
        latest = [:]
    }

    func value(_ pid: OBDPID) -> Double? { latest[pid]?.value }

    // MARK: Alerts and trouble codes

    /// Records a fresh trouble-code read, from the background poll or from the codes screen.
    func noteTroubleCodes(_ codes: [String]) {
        let previous = Set(troubleCodes)
        troubleCodes = codes
        hasReadCodes = true
        // Alerts for codes the car no longer reports go away; new codes add one.
        alerts.removeAll { $0.kind == .checkEngine && !codes.contains(String($0.id.dropFirst("code-".count))) }
        for alert in DriveAlerts.newCodes(previous: previous, current: codes) where !alerts.contains(alert) {
            alerts.append(alert)
        }
    }

    private func checkCoolant(in readings: [OBDReading]) {
        guard let reading = readings.last(where: { $0.pid == .coolantTemperature }) else { return }
        let result = DriveAlerts.coolant(celsius: reading.value, wasHot: coolantHot)
        coolantHot = result.isHot
        if let alert = result.alert, !alerts.contains(alert) { alerts.append(alert) }
        if !result.isHot { alerts.removeAll { $0.kind == .coolantHot } }
    }

    /// Asks the car for trouble codes now and then while connected, so a new check-engine
    /// light is noticed without anyone opening the codes screen.
    private func startCodePolling() {
        guard codeTask == nil else { return }
        codeTask = Task { [weak self, source] in
            while !Task.isCancelled {
                if let codes = try? await source.readTroubleCodes() {
                    guard let self, !Task.isCancelled else { return }
                    self.noteTroubleCodes(codes)
                }
                try? await Task.sleep(for: Self.codeInterval)
            }
        }
    }

    private func stopCodePolling() {
        codeTask?.cancel()
        codeTask = nil
        troubleCodes = []
        hasReadCodes = false
        alerts = []
        coolantHot = false
    }
}
