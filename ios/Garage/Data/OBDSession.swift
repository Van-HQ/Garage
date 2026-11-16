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
                case .readings(let readings):
                    for reading in readings { self.latest[reading.pid] = reading }
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        state = .disconnected
        latest = [:]
    }

    func value(_ pid: OBDPID) -> Double? { latest[pid]?.value }
}
