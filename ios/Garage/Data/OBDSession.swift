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

    let source: OBDDataSource
    private var task: Task<Void, Never>?

    /// Called with every batch of readings, as they arrive. Trip recording listens here.
    var onReadings: (([OBDReading]) -> Void)?
    /// Called when the connection ends: stopped by the user, dropped, or failed.
    var onDisconnect: (() -> Void)?

    init(source: OBDDataSource) {
        self.source = source
    }

    var isActive: Bool { task != nil }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, source] in
            for await event in source.events() {
                guard let self, !Task.isCancelled else { break }
                switch event {
                case .state(let state):
                    self.state = state
                    switch state {
                    case .disconnected, .failed: self.onDisconnect?()
                    default: break
                    }
                case .readings(let readings):
                    for reading in readings { self.latest[reading.pid] = reading }
                    self.onReadings?(readings)
                }
            }
        }
    }

    func stop() {
        onDisconnect?()
        task?.cancel()
        task = nil
        state = .disconnected
        latest = [:]
    }

    func value(_ pid: OBDPID) -> Double? { latest[pid]?.value }
}
