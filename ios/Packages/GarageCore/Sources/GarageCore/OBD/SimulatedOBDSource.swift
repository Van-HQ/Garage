import Foundation

/// A made-up but plausible drive, as a pure function of elapsed time: idle,
/// pull away, cruise in town, speed up to highway pace, cruise, then brake to a stop.
/// The loop repeats every `cycleLength` seconds. No randomness, so tests can pin values.
public enum SimulatedDrive {
    public static let cycleLength: TimeInterval = 90

    /// Vehicle speed in km/h.
    public static func speed(at elapsed: TimeInterval) -> Double {
        let t = elapsed.truncatingRemainder(dividingBy: cycleLength)
        func ramp(_ from: Double, _ to: Double, _ start: Double, _ end: Double) -> Double {
            let progress = (t - start) / (end - start)
            // Smoothstep, so acceleration eases in and out like a real driver.
            let eased = progress * progress * (3 - 2 * progress)
            return from + (to - from) * eased
        }
        switch t {
        case ..<8: return 0
        case ..<20: return ramp(0, 65, 8, 20)
        case ..<45: return 65 + 2 * sin(t / 3)
        case ..<60: return ramp(65 + 2 * sin(45.0 / 3), 110, 45, 60)
        case ..<75: return 110 + 1.5 * sin(t / 2.5)
        case ..<88: return ramp(110 + 1.5 * sin(75.0 / 2.5), 0, 75, 88)
        default: return 0
        }
    }

    /// Positive when speeding up, in km/h per second.
    static func acceleration(at elapsed: TimeInterval) -> Double {
        (speed(at: elapsed + 0.25) - speed(at: elapsed - 0.25)) / 0.5
    }

    public static func value(of pid: OBDPID, at elapsed: TimeInterval) -> Double {
        let kmh = speed(at: elapsed)
        let accel = acceleration(at: elapsed)
        switch pid {
        case .speed:
            return kmh
        case .rpm:
            guard kmh > 1 else { return 720 + 15 * sin(elapsed * 2) }
            // Rough 6-speed automatic: engine speed per km/h falls as the gearbox shifts up.
            let ratio: Double = kmh < 20 ? 95 : kmh < 40 ? 58 : kmh < 65 ? 38 : kmh < 90 ? 27 : 21
            return min(5200, max(900, kmh * ratio / 1.4 + max(accel, 0) * 110))
        case .throttlePosition:
            return kmh < 1 ? 14 : min(85, max(12, 16 + kmh * 0.12 + accel * 7))
        case .engineLoad:
            return kmh < 1 ? 24 : min(95, max(12, 22 + kmh * 0.18 + accel * 9))
        case .coolantTemperature:
            // Warms from a cold start to operating temperature over about five minutes.
            return min(90, 22 + elapsed * 0.24) + (elapsed > 300 ? sin(elapsed / 20) : 0)
        case .intakeAirTemperature:
            return 27 + 3 * sin(elapsed / 40)
        case .shortTermFuelTrim:
            return 2.5 * sin(elapsed / 4)
        case .longTermFuelTrim:
            return 1.6
        case .fuelLevel:
            return max(5, 62 - elapsed / 600)
        case .controlModuleVoltage:
            return 14.1 + 0.1 * sin(elapsed / 6)
        }
    }

    /// The reply an adapter would send for this PID at this moment, such as "41 0C 0B 40".
    public static func reply(for pid: OBDPID, at elapsed: TimeInterval) -> String {
        let bytes = [0x41, pid.rawValue] + pid.encode(value(of: pid, at: elapsed))
        return bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

/// An `OBDDataSource` that needs no hardware. It builds adapter-style replies
/// from `SimulatedDrive` and runs them through the real ELM327 parser, so the
/// phone app, trip logging and CarPlay can all be built and tested without a dongle.
public final class SimulatedOBDSource: OBDDataSource, @unchecked Sendable {
    public let displayName = "Simulator"

    private let plan: OBDSamplingPlan
    private let connectDelay: Duration
    private let lock = NSLock()
    private var storedCodes: [String]

    public init(
        plan: OBDSamplingPlan = .standard,
        connectDelay: Duration = .milliseconds(700),
        storedCodes: [String] = ["P0456"]
    ) {
        self.plan = plan
        self.connectDelay = connectDelay
        self.storedCodes = storedCodes
    }

    public func events() -> AsyncStream<OBDEvent> {
        let plan = plan
        let connectDelay = connectDelay
        return AsyncStream { continuation in
            let task = Task {
                continuation.yield(.state(.connecting))
                try? await Task.sleep(for: connectDelay)
                guard !Task.isCancelled else { return }
                continuation.yield(.state(.connected(adapter: "Simulator")))

                let start = Date()
                var lastSlow = -TimeInterval.infinity
                while !Task.isCancelled {
                    let now = Date()
                    let elapsed = now.timeIntervalSince(start)
                    var pids = plan.fastPIDs
                    if elapsed - lastSlow >= plan.slowInterval {
                        pids += plan.slowPIDs
                        lastSlow = elapsed
                    }
                    let readings = pids.compactMap { pid -> OBDReading? in
                        let reply = SimulatedDrive.reply(for: pid, at: elapsed)
                        return ELM327.parseLiveData(reply, for: pid).map {
                            OBDReading(pid: pid, value: $0, timestamp: now)
                        }
                    }
                    continuation.yield(.readings(readings))
                    try? await Task.sleep(for: .seconds(plan.fastInterval))
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func readTroubleCodes() async throws -> [String] {
        let codes = lock.withLock { storedCodes }
        // Round-trip through the adapter format, like the live values.
        var bytes: [UInt8] = [0x43]
        for code in codes {
            if let pair = ELM327.bytes(forTroubleCode: code) { bytes += [pair.0, pair.1] }
        }
        while bytes.count < 7 { bytes.append(0) }
        return ELM327.parseTroubleCodes(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
    }

    public func clearTroubleCodes() async throws {
        lock.withLock { storedCodes = [] }
    }
}
