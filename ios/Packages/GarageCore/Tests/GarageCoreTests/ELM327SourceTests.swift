import XCTest
@testable import GarageCore

/// An adapter that exists only in memory. Answers like a real ELM327, with drive data from `SimulatedDrive`.
private final class FakeTransport: OBDTransport, @unchecked Sendable {
    let name = "Fake adapter"
    private let lock = NSLock()
    private var log: [String] = []
    var probeReply = "41 00 BE 3F A8 13"
    var silentAfter: Int?          // go quiet after this many commands, to test a lost adapter
    var codesReply = "43 01 33 00 00 00 00"
    var clearReply = "44"

    var commands: [String] { lock.lock(); defer { lock.unlock() }; return log }

    func send(_ command: String, timeout: Duration) async throws -> String {
        lock.lock()
        log.append(command)
        let count = log.count
        lock.unlock()
        if let silentAfter, count > silentAfter { throw OBDLinkError.timeout }
        switch command {
        case "0100": return probeReply
        case "03": return codesReply
        case "04": return clearReply
        case _ where command.hasPrefix("AT"): return "OK"
        default:
            guard command.count == 4, let raw = UInt8(command.dropFirst(2), radix: 16), let pid = OBDPID(rawValue: raw)
            else { return "NO DATA" }
            return SimulatedDrive.reply(for: pid, at: 30)
        }
    }

    func close() async {}
}

final class ELM327SourceTests: XCTestCase {
    private let fastPlan = OBDSamplingPlan(fastPIDs: [.rpm, .speed], slowPIDs: [.fuelLevel], fastInterval: 0.01, slowInterval: 0.05)

    private func source(_ transport: FakeTransport, failures: Int = 6) -> ELM327Source {
        ELM327Source(plan: fastPlan, commandTimeout: .milliseconds(50), startupTimeout: .milliseconds(200), maxConsecutiveFailures: failures) { transport }
    }

    func testConnectsRunsSetupThenStreamsReadings() async {
        let transport = FakeTransport()
        let events = source(transport).events()
        var states: [OBDConnectionState] = []
        var speeds: [Double] = []
        for await event in events {
            switch event {
            case .state(let state): states.append(state)
            case .readings(let readings):
                speeds += readings.filter { $0.pid == .speed }.map(\.value)
            }
            if speeds.count >= 2 { break }
        }
        XCTAssertEqual(states.first, .connecting)
        XCTAssertTrue(states.contains(.connected(adapter: "Fake adapter")))
        XCTAssertEqual(speeds.first!, SimulatedDrive.speed(at: 30), accuracy: 1)
        // Setup runs in order before any live PID.
        XCTAssertEqual(Array(transport.commands.prefix(7)), ["ATZ", "ATE0", "ATL0", "ATS1", "ATH0", "ATSP0", "0100"])
    }

    func testIgnitionOffFailsWithAClearMessage() async {
        let transport = FakeTransport()
        transport.probeReply = "UNABLE TO CONNECT"
        var failure: String?
        for await event in source(transport).events() {
            if case .state(.failed(let message)) = event { failure = message }
        }
        XCTAssertEqual(failure?.contains("ignition"), true)
    }

    func testLosingTheAdapterFailsInsteadOfHangingForever() async {
        let transport = FakeTransport()
        transport.silentAfter = 12
        var failure: String?
        for await event in source(transport, failures: 3).events() {
            if case .state(.failed(let message)) = event { failure = message }
        }
        XCTAssertEqual(failure?.contains("Lost the adapter"), true)
    }

    func testReadsAndClearsTroubleCodesWhileConnected() async throws {
        let transport = FakeTransport()
        let src = source(transport)
        let events = src.events()
        let reader = Task { () -> ([String], Bool) in
            var connected = false
            for await event in events {
                if case .state(.connected) = event { connected = true; break }
            }
            guard connected else { return ([], false) }
            let codes = try await src.readTroubleCodes()
            try await src.clearTroubleCodes()
            return (codes, true)
        }
        let (codes, ok) = try await reader.value
        XCTAssertTrue(ok)
        XCTAssertEqual(codes, ["P0133"])
        XCTAssertTrue(transport.commands.contains("04"))
    }

    func testTroubleCodesThrowWhenNotConnected() async {
        let src = source(FakeTransport())
        do {
            _ = try await src.readTroubleCodes()
            XCTFail("expected notConnected")
        } catch {
            XCTAssertEqual(error as? OBDLinkError, .notConnected)
        }
    }

    func testRefusedClearIsReported() async throws {
        let transport = FakeTransport()
        transport.clearReply = "7F 04 22"
        let src = source(transport)
        let events = src.events()
        let task = Task { () -> Bool in
            for await event in events { if case .state(.connected) = event { break } }
            do { try await src.clearTroubleCodes(); return false } catch { return true }
        }
        let refused = await task.value
        XCTAssertTrue(refused)
    }
}
