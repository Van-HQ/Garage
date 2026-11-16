import XCTest
@testable import GarageCore

final class OBDTests: XCTestCase {
    // Worked examples from the SAE J1979 formulas.
    func testDecodeFormulas() {
        XCTAssertEqual(OBDPID.rpm.decode([0x1A, 0xF8]), 1726)
        XCTAssertEqual(OBDPID.speed.decode([0x64]), 100)
        XCTAssertEqual(OBDPID.coolantTemperature.decode([0x7B]), 83)
        XCTAssertEqual(OBDPID.intakeAirTemperature.decode([0x28]), 0)
        XCTAssertEqual(OBDPID.throttlePosition.decode([0xFF])!, 100, accuracy: 0.001)
        XCTAssertEqual(OBDPID.engineLoad.decode([0x80])!, 50.196, accuracy: 0.001)
        XCTAssertEqual(OBDPID.shortTermFuelTrim.decode([0x80]), 0)
        XCTAssertEqual(OBDPID.longTermFuelTrim.decode([0x00]), -100)
        XCTAssertEqual(OBDPID.fuelLevel.decode([0x7F])!, 49.804, accuracy: 0.001)
        XCTAssertEqual(OBDPID.controlModuleVoltage.decode([0x37, 0x14])!, 14.1, accuracy: 0.0001)
    }

    func testDecodeNeedsEnoughBytes() {
        XCTAssertNil(OBDPID.rpm.decode([0x1A]))
        XCTAssertNil(OBDPID.speed.decode([]))
    }

    func testEncodeRoundTripsWithinOneStep() {
        let samples: [(OBDPID, Double, Double)] = [
            (.rpm, 2350.25, 0.25), (.speed, 97, 1), (.coolantTemperature, 88, 1),
            (.throttlePosition, 33.3, 0.4), (.shortTermFuelTrim, -3.9, 0.8),
            (.fuelLevel, 61.2, 0.4), (.controlModuleVoltage, 13.987, 0.001),
        ]
        for (pid, value, step) in samples {
            let decoded = pid.decode(pid.encode(value))!
            XCTAssertEqual(decoded, value, accuracy: step, "\(pid)")
        }
    }

    func testCommands() {
        XCTAssertEqual(OBDPID.rpm.command, "010C")
        XCTAssertEqual(OBDPID.controlModuleVoltage.command, "0142")
    }

    func testParseLiveDataVariants() {
        XCTAssertEqual(ELM327.parseLiveData("41 0C 1A F8", for: .rpm), 1726)
        XCTAssertEqual(ELM327.parseLiveData("410C1AF8", for: .rpm), 1726)
        XCTAssertEqual(ELM327.parseLiveData("41 0c 1a f8\r\n>", for: .rpm), 1726)
        // With CAN headers on: module address, then a length byte.
        XCTAssertEqual(ELM327.parseLiveData("7E8 04 41 0C 1A F8", for: .rpm), 1726)
        XCTAssertEqual(ELM327.parseLiveData("7E804410C1AF8", for: .rpm), 1726, "headers on, spaces off")
        // Status text before the answer.
        XCTAssertEqual(ELM327.parseLiveData("SEARCHING...\r41 0D 3C\r\r>", for: .speed), 60)
        // Two modules answering: the first usable line wins.
        XCTAssertEqual(ELM327.parseLiveData("7E8 03 41 0D 3C\r7E9 03 41 0D 3C", for: .speed), 60)
    }

    func testParseLiveDataRejectsNonAnswers() {
        XCTAssertNil(ELM327.parseLiveData("NO DATA", for: .rpm))
        XCTAssertNil(ELM327.parseLiveData("?", for: .rpm))
        XCTAssertNil(ELM327.parseLiveData("UNABLE TO CONNECT", for: .rpm))
        XCTAssertNil(ELM327.parseLiveData("41 0D 3C", for: .rpm), "a reply to a different PID")
        XCTAssertNil(ELM327.parseLiveData("41 0C 1A", for: .rpm), "truncated")
        XCTAssertNil(ELM327.parseLiveData("", for: .rpm))
    }

    func testTroubleCodeDecoding() {
        XCTAssertEqual(ELM327.troubleCode(0x01, 0x33), "P0133")
        XCTAssertEqual(ELM327.troubleCode(0x04, 0x56), "P0456")
        XCTAssertEqual(ELM327.troubleCode(0x41, 0x23), "C0123")
        XCTAssertEqual(ELM327.troubleCode(0x92, 0x34), "B1234")
        XCTAssertEqual(ELM327.troubleCode(0xC1, 0x00), "U0100")
        XCTAssertNil(ELM327.troubleCode(0, 0))
    }

    func testParseTroubleCodes() {
        XCTAssertEqual(ELM327.parseTroubleCodes("43 01 33 00 00 00 00"), ["P0133"])
        XCTAssertEqual(ELM327.parseTroubleCodes("43 01 33 04 56 C1 00"), ["P0133", "P0456", "U0100"])
        // CAN format: a count byte comes first.
        XCTAssertEqual(ELM327.parseTroubleCodes("43 02 01 33 04 56"), ["P0133", "P0456"])
        XCTAssertEqual(ELM327.parseTroubleCodes("7E8 06 43 02 01 33 04 56"), ["P0133", "P0456"])
        XCTAssertEqual(ELM327.parseTroubleCodes("43 00"), [])
        XCTAssertEqual(ELM327.parseTroubleCodes("43 00 00 00 00 00 00"), [])
        XCTAssertEqual(ELM327.parseTroubleCodes("NO DATA"), [])
    }

    func testTroubleCodeBytesRoundTrip() {
        for code in ["P0133", "P0456", "C0123", "B1234", "U0100", "P2A00"] {
            let pair = ELM327.bytes(forTroubleCode: code)
            XCTAssertNotNil(pair, code)
            XCTAssertEqual(ELM327.troubleCode(pair!.0, pair!.1), code)
        }
        XCTAssertNil(ELM327.bytes(forTroubleCode: "X0000"))
        XCTAssertNil(ELM327.bytes(forTroubleCode: "P4000"))
    }

    func testSimulatedDriveShape() {
        XCTAssertEqual(SimulatedDrive.speed(at: 3), 0)
        XCTAssertEqual(SimulatedDrive.speed(at: 30), 65, accuracy: 2.1)
        XCTAssertEqual(SimulatedDrive.speed(at: 70), 110, accuracy: 1.6)
        XCTAssertEqual(SimulatedDrive.speed(at: 89), 0)
        // The loop repeats.
        XCTAssertEqual(SimulatedDrive.speed(at: 30), SimulatedDrive.speed(at: 30 + SimulatedDrive.cycleLength), accuracy: 0.0001)
        // Idles when stopped, revs when moving, never past the limiter.
        XCTAssertEqual(SimulatedDrive.value(of: .rpm, at: 3), 720, accuracy: 16)
        for second in stride(from: 0.0, to: 180, by: 0.5) {
            let rpm = SimulatedDrive.value(of: .rpm, at: second)
            XCTAssertTrue((600...5200).contains(rpm), "rpm \(rpm) at \(second)s")
            XCTAssertTrue((0...115).contains(SimulatedDrive.speed(at: second)))
        }
    }

    func testSimulatedRepliesParseBackToTheirValues() {
        for pid in OBDPID.allCases {
            for second in [0.0, 12.5, 33, 52, 70, 80] {
                let reply = SimulatedDrive.reply(for: pid, at: second)
                let parsed = ELM327.parseLiveData(reply, for: pid)
                XCTAssertNotNil(parsed, "\(pid) at \(second)s: \(reply)")
                XCTAssertEqual(parsed!, SimulatedDrive.value(of: pid, at: second), accuracy: pid == .rpm ? 0.25 : 1, "\(pid)")
            }
        }
    }

    func testSimulatorStreamsConnectsThenReads() async throws {
        let plan = OBDSamplingPlan(fastPIDs: [.rpm, .speed], slowPIDs: [.fuelLevel], fastInterval: 0.02, slowInterval: 10)
        let source = SimulatedOBDSource(plan: plan, connectDelay: .milliseconds(5))
        var states: [OBDConnectionState] = []
        var batches: [[OBDReading]] = []
        for await event in source.events() {
            switch event {
            case .state(let state): states.append(state)
            case .readings(let readings): batches.append(readings)
            }
            if batches.count == 3 { break }
        }
        XCTAssertEqual(states, [.connecting, .connected(adapter: "Simulator")])
        // The first batch includes the slow values; later ones only the fast ones until the slow interval passes.
        XCTAssertEqual(batches[0].map(\.pid), [.rpm, .speed, .fuelLevel])
        XCTAssertEqual(batches[1].map(\.pid), [.rpm, .speed])
    }

    func testSimulatorTroubleCodes() async throws {
        let source = SimulatedOBDSource(storedCodes: ["P0456", "P0171"])
        let codes = try await source.readTroubleCodes()
        XCTAssertEqual(codes, ["P0456", "P0171"])
        try await source.clearTroubleCodes()
        let after = try await source.readTroubleCodes()
        XCTAssertEqual(after, [])
    }
}
