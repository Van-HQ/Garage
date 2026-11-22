import XCTest
@testable import GarageCore

final class TripRecorderTests: XCTestCase {
    let vehicle = UUID()
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func reading(_ pid: OBDPID, _ value: Double, at seconds: Double) -> OBDReading {
        OBDReading(pid: pid, value: value, timestamp: t0.addingTimeInterval(seconds))
    }

    /// Speed readings every `step` seconds from `from` to `to` at a constant speed.
    func steady(_ kmh: Double, from: Double, to: Double, step: Double = 1) -> [OBDReading] {
        stride(from: from, through: to, by: step).map { reading(.speed, kmh, at: $0) }
    }

    func testConstantSpeedDistance() {
        var recorder = TripRecorder(vehicleID: vehicle)
        // 60 km/h for 10 minutes is exactly 10 km.
        XCTAssertNil(recorder.ingest(steady(60, from: 0, to: 600)))
        let trip = recorder.finish()
        XCTAssertNotNil(trip)
        XCTAssertEqual(trip!.distanceMiles, 10 / kilometersPerMile, accuracy: 0.001)
        XCTAssertEqual(trip!.avgSpeedMph!, 60 / kilometersPerMile, accuracy: 0.01)
        XCTAssertEqual(trip!.maxSpeedMph!, 60 / kilometersPerMile, accuracy: 0.0001)
        XCTAssertEqual(trip!.duration, 600, accuracy: 0.0001)
        XCTAssertEqual(trip!.distanceSource, "obd")
    }

    func testDoesNotStartWhileStopped() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(0, from: 0, to: 120))
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.progress)
        XCTAssertNil(recorder.finish())
    }

    func testStartsOnFirstMovingReadingAndKeepsTheRampUp() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(0, from: 0, to: 9))
        // Speeds up from rest: 0 at 10 s, 20 at 11 s, 40 at 12 s.
        _ = recorder.ingest([reading(.speed, 0, at: 10), reading(.speed, 20, at: 11), reading(.speed, 40, at: 12)])
        XCTAssertTrue(recorder.isRecording)
        // The trip starts at the last stopped reading (10 s), so the first second of acceleration is counted.
        XCTAssertEqual(recorder.progress!.startedAt, t0.addingTimeInterval(10))
        // Trapezoids: (0+20)/2*1 + (20+40)/2*1 = 40 km·s → 40/3600 km.
        XCTAssertEqual(recorder.progress!.distanceMiles * kilometersPerMile, 40.0 / 3600, accuracy: 0.0001)
    }

    func testEndsAfterBeingStoppedAndExcludesTheWait() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(50, from: 0, to: 300))
        // Stopped from 301 s on; the 180 s rule fires at 481 s.
        var trip: RecordedTrip?
        for second in stride(from: 301.0, through: 600, by: 1) {
            if let ended = recorder.ingest([reading(.speed, 0, at: second)]) { trip = ended; break }
        }
        XCTAssertNotNil(trip)
        XCTAssertFalse(recorder.isRecording)
        // The trip ends when the vehicle last moved, not three minutes later.
        XCTAssertEqual(trip!.endedAt, t0.addingTimeInterval(300))
        XCTAssertEqual(trip!.distanceMiles * kilometersPerMile, 50.0 * 300 / 3600, accuracy: 0.01)
    }

    func testShortStopDoesNotEndTheTrip() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(50, from: 0, to: 100))
        _ = recorder.ingest(steady(0, from: 101, to: 200))   // red light, 100 s
        let trip = recorder.ingest(steady(50, from: 201, to: 300))
        XCTAssertNil(trip)
        XCTAssertTrue(recorder.isRecording)
        let final = recorder.finish()
        // One trip across the stop; time stopped is not "moving time".
        XCTAssertNotNil(final)
        XCTAssertLessThan(final!.avgSpeedMph!, final!.maxSpeedMph!)
    }

    func testGapsInTheDataAreNotCountedAsDriving() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(60, from: 0, to: 60))
        // The adapter drops out for 5 minutes, then comes back at the same speed.
        _ = recorder.ingest(steady(60, from: 360, to: 420))
        let trip = recorder.finish()!
        // Only the 120 seconds with data count: 60 km/h * 120 s = 2 km.
        XCTAssertEqual(trip.distanceMiles * kilometersPerMile, 2, accuracy: 0.01)
    }

    func testTinyTripsAreDropped() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(10, from: 0, to: 30))   // ~83 m
        XCTAssertTrue(recorder.isRecording)
        XCTAssertNil(recorder.finish())
        XCTAssertFalse(recorder.isRecording)
    }

    func testSamplingIsOncePerIntervalPerValue() {
        var recorder = TripRecorder(vehicleID: vehicle)
        var readings: [OBDReading] = []
        for second in stride(from: 0.0, through: 600, by: 0.5) {
            readings.append(reading(.speed, 60, at: second))
            readings.append(reading(.rpm, 2000, at: second))
        }
        _ = recorder.ingest(readings)
        let trip = recorder.finish()!
        let speedSamples = trip.samples.filter { $0.pid == Int(OBDPID.speed.rawValue) }
        let rpmSamples = trip.samples.filter { $0.pid == Int(OBDPID.rpm.rawValue) }
        // 0, 15, 30 ... 600 s.
        XCTAssertEqual(speedSamples.count, 41)
        XCTAssertEqual(rpmSamples.count, 41)
        XCTAssertEqual(speedSamples[1].recordedAt.timeIntervalSince(speedSamples[0].recordedAt), 15)
        // Nothing near the full 2 x 1,201 readings is kept.
        XCTAssertEqual(trip.samples.count, 82)
    }

    func testMaximumsAndFuel() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest([
            reading(.speed, 60, at: 0), reading(.fuelLevel, 61.0, at: 0), reading(.coolantTemperature, 70, at: 0),
        ])
        _ = recorder.ingest(steady(100, from: 1, to: 600))
        _ = recorder.ingest([
            reading(.rpm, 3100, at: 100), reading(.rpm, 5200, at: 200), reading(.rpm, 2000, at: 300),
            reading(.coolantTemperature, 92, at: 400), reading(.coolantTemperature, 88, at: 500),
            reading(.fuelLevel, 60.2, at: 599),
        ])
        let trip = recorder.finish()!
        XCTAssertEqual(trip.maxRPM, 5200)
        XCTAssertEqual(trip.maxCoolantC, 92)
        XCTAssertEqual(trip.fuelUsedPercent!, 0.8, accuracy: 0.0001)
        XCTAssertEqual(trip.maxSpeedMph!, 100 / kilometersPerMile, accuracy: 0.0001)
    }

    func testRefuelingMidTripLeavesFuelUnknown() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest([reading(.fuelLevel, 20, at: 0)])  // before the trip: ignored
        _ = recorder.ingest(steady(80, from: 0, to: 300))
        _ = recorder.ingest([reading(.fuelLevel, 20, at: 1), reading(.fuelLevel, 95, at: 290)])
        XCTAssertNil(recorder.finish()!.fuelUsedPercent)
    }

    func testUnknownValuesStayNil() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(60, from: 0, to: 300))
        let trip = recorder.finish()!
        XCTAssertNil(trip.maxRPM)
        XCTAssertNil(trip.maxCoolantC)
        XCTAssertNil(trip.fuelUsedPercent)
    }

    func testBackToBackTripsAreSeparate() {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(60, from: 0, to: 300))
        let first = recorder.ingest(steady(0, from: 301, to: 500))
        XCTAssertNotNil(first)
        XCTAssertNil(recorder.ingest(steady(60, from: 600, to: 900)))
        XCTAssertTrue(recorder.isRecording)
        let second = recorder.finish()
        XCTAssertNotNil(second)
        XCTAssertNotEqual(first!.id, second!.id)
        XCTAssertGreaterThan(second!.startedAt, first!.endedAt)
    }

    func testReadingsInABatchAreOrderedByTime() {
        var shuffled = TripRecorder(vehicleID: vehicle)
        var ordered = TripRecorder(vehicleID: vehicle)
        let readings = steady(60, from: 0, to: 120)
        _ = shuffled.ingest(readings.shuffled())
        _ = ordered.ingest(readings)
        XCTAssertEqual(shuffled.finish()!.distanceMiles, ordered.finish()!.distanceMiles, accuracy: 0.0001)
    }

    func testTripCodableRoundTrip() throws {
        var recorder = TripRecorder(vehicleID: vehicle)
        _ = recorder.ingest(steady(60, from: 0, to: 300) + [reading(.rpm, 2100, at: 10)])
        let trip = recorder.finish()!
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RecordedTrip.self, from: encoder.encode(trip))
        XCTAssertEqual(decoded, trip)
    }

    /// A full pass through the simulator's drive cycle, integrated independently with a very fine step.
    func testSimulatedDriveDistance() {
        var recorder = TripRecorder(vehicleID: vehicle)
        var readings: [OBDReading] = []
        for step in 0...(Int(SimulatedDrive.cycleLength * 2)) {
            let elapsed = Double(step) * 0.5
            readings.append(OBDReading(pid: .speed, value: SimulatedDrive.value(of: .speed, at: elapsed), timestamp: t0.addingTimeInterval(elapsed)))
        }
        _ = recorder.ingest(readings)
        let trip = recorder.finish()!

        // Reference: 0.01 s steps over the stretch the trip covers.
        let from = trip.startedAt.timeIntervalSince(t0)
        let to = trip.endedAt.timeIntervalSince(t0)
        var km = 0.0
        var s = from
        while s < to {
            km += SimulatedDrive.speed(at: s) * 0.01 / 3600
            s += 0.01
        }
        XCTAssertEqual(trip.distanceMiles * kilometersPerMile, km, accuracy: km * 0.01)
        XCTAssertGreaterThan(km, 1)
    }
}

final class TripRecorderGPSTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func speed(_ kmh: Double, at seconds: TimeInterval) -> OBDReading {
        OBDReading(pid: .speed, value: kmh, timestamp: start.addingTimeInterval(seconds))
    }

    /// Drives 60 km/h for `seconds`, one reading a second, then stops long enough to end the trip.
    private func drive(_ recorder: inout TripRecorder, from: TimeInterval, seconds: Int, fromGPS: Bool) -> RecordedTrip? {
        var trip: RecordedTrip?
        for i in 0..<seconds {
            if let t = recorder.ingest([speed(60, at: from + TimeInterval(i))], fromGPS: fromGPS) { trip = t }
        }
        return trip
    }

    func testGPSOnlyTripIsLabelledGPS() {
        var recorder = TripRecorder(vehicleID: UUID())
        _ = drive(&recorder, from: 0, seconds: 120, fromGPS: true)
        let trip = recorder.finish()
        XCTAssertEqual(trip?.distanceSource, "gps")
        // 60 km/h for ~2 minutes is about 2 km, 1.2 miles.
        XCTAssertEqual(trip?.distanceMiles ?? 0, 1.2, accuracy: 0.1)
    }

    func testCarOnlyTripStaysOBD() {
        var recorder = TripRecorder(vehicleID: UUID())
        _ = drive(&recorder, from: 0, seconds: 120, fromGPS: false)
        XCTAssertEqual(recorder.finish()?.distanceSource, "obd")
    }

    func testSwitchingSourceMidTripIsMixed() {
        var recorder = TripRecorder(vehicleID: UUID())
        _ = drive(&recorder, from: 0, seconds: 60, fromGPS: false)
        _ = drive(&recorder, from: 60, seconds: 60, fromGPS: true)
        let trip = recorder.finish()
        XCTAssertEqual(trip?.distanceSource, "mixed")
        XCTAssertEqual(trip?.distanceMiles ?? 0, 1.2, accuracy: 0.1)
    }
}
