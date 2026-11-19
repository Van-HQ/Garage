import Foundation

/// One saved sample of a value during a trip.
public struct TripSample: Codable, Hashable, Sendable {
    /// `OBDPID.rawValue`; stored as a plain number so old trips keep decoding if PIDs are added later.
    public let pid: Int
    public let value: Double
    public let recordedAt: Date

    public init(pid: Int, value: Double, recordedAt: Date) {
        self.pid = pid; self.value = value; self.recordedAt = recordedAt
    }
}

/// A finished drive: summary numbers plus the downsampled readings.
public struct RecordedTrip: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let vehicleID: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let distanceMiles: Double
    /// Distance over the time spent moving, not counting stops.
    public let avgSpeedMph: Double?
    public let maxSpeedMph: Double?
    public let maxRPM: Double?
    public let maxCoolantC: Double?
    /// How far the fuel gauge dropped, in points of a full tank. Nil if unknown or the tank was filled mid-trip.
    public let fuelUsedPercent: Double?
    public let distanceSource: String
    public let samples: [TripSample]

    public init(
        id: UUID, vehicleID: UUID, startedAt: Date, endedAt: Date, distanceMiles: Double,
        avgSpeedMph: Double?, maxSpeedMph: Double?, maxRPM: Double?, maxCoolantC: Double?,
        fuelUsedPercent: Double?, distanceSource: String = "obd", samples: [TripSample]
    ) {
        self.id = id; self.vehicleID = vehicleID; self.startedAt = startedAt; self.endedAt = endedAt
        self.distanceMiles = distanceMiles; self.avgSpeedMph = avgSpeedMph; self.maxSpeedMph = maxSpeedMph
        self.maxRPM = maxRPM; self.maxCoolantC = maxCoolantC; self.fuelUsedPercent = fuelUsedPercent
        self.distanceSource = distanceSource; self.samples = samples
    }

    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}

public let kilometersPerMile = 1.609344

/// Watches the stream of OBD readings and cuts it into trips. Pure logic: it
/// only reads the timestamps on the readings, so tests can replay any drive.
///
/// A trip starts when the vehicle starts moving and ends once it has been
/// stopped for `endAfterStopped` seconds (or when `finish` is called). Distance
/// is the integral of vehicle speed, with gaps in the data not counted as driving.
public struct TripRecorder: Sendable {
    public struct Settings: Sendable {
        /// Speed that counts as "moving", in km/h.
        public var movingKmh = 5.0
        /// Speed below which the vehicle counts as stopped, in km/h.
        public var stoppedKmh = 1.0
        /// A stop this long ends the trip.
        public var endAfterStopped: TimeInterval = 180
        /// One saved sample of each value per this many seconds.
        public var sampleInterval: TimeInterval = 15
        /// Gaps in the speed data longer than this aren't counted as driving.
        public var maxGap: TimeInterval = 5
        /// Trips shorter than this are dropped as noise (a car moved in a parking lot).
        public var minDistanceMiles = 0.1

        public init() {}
    }

    public struct Progress: Sendable, Equatable {
        public var startedAt: Date
        public var distanceMiles: Double
        public var lastUpdate: Date
    }

    public let settings: Settings
    public let vehicleID: UUID

    private struct Active {
        var startedAt: Date
        var lastMovingAt: Date
        var distanceKm = 0.0
        var movingSeconds = 0.0
        var lastSpeed: (kmh: Double, at: Date)?
        var stoppedSince: Date?
        var maxSpeedKmh = 0.0
        var maxRPM: Double?
        var maxCoolant: Double?
        var firstFuel: Double?
        var lastFuel: Double?
        var lastSampleAt: [OBDPID: Date] = [:]
        var samples: [TripSample] = []
        var lastUpdate: Date
    }

    private var active: Active?
    private var lastSeenSpeed: (kmh: Double, at: Date)?

    public init(vehicleID: UUID, settings: Settings = Settings()) {
        self.vehicleID = vehicleID
        self.settings = settings
    }

    /// Nil when no trip is in progress.
    public var progress: Progress? {
        active.map { Progress(startedAt: $0.startedAt, distanceMiles: $0.distanceKm / kilometersPerMile, lastUpdate: $0.lastUpdate) }
    }

    public var isRecording: Bool { active != nil }

    /// Feeds one batch of readings in. Returns a finished trip when this batch ended one.
    public mutating func ingest(_ readings: [OBDReading]) -> RecordedTrip? {
        var finished: RecordedTrip?
        for reading in readings.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let trip = ingest(reading) { finished = trip }
        }
        return finished
    }

    /// Ends the trip in progress now (the user tapped End, or the adapter disconnected).
    /// Returns nil if nothing was recording or the trip was too short to keep.
    public mutating func finish() -> RecordedTrip? {
        guard let current = active else { return nil }
        active = nil
        lastSeenSpeed = nil
        return build(current, endedAt: current.lastMovingAt)
    }

    private mutating func ingest(_ reading: OBDReading) -> RecordedTrip? {
        if reading.pid == .speed { return ingestSpeed(reading) }
        guard var current = active else { return nil }
        record(reading, into: &current)
        current.lastUpdate = max(current.lastUpdate, reading.timestamp)
        active = current
        return nil
    }

    private mutating func ingestSpeed(_ reading: OBDReading) -> RecordedTrip? {
        let kmh = reading.value
        let now = reading.timestamp
        defer { lastSeenSpeed = (kmh, now) }

        guard var current = active else {
            // Idle: start a trip on the first moving reading.
            guard kmh >= settings.movingKmh else { return nil }
            var started = Active(startedAt: now, lastMovingAt: now, lastUpdate: now)
            // Count the stretch from the previous (slower) reading, so the trip's first seconds aren't lost.
            if let previous = lastSeenSpeed, now.timeIntervalSince(previous.at) <= settings.maxGap {
                started.startedAt = previous.at
                accumulate(&started, from: previous, to: (kmh, now))
            }
            record(reading, into: &started)
            started.lastSpeed = (kmh, now)
            active = started
            return nil
        }

        if let previous = current.lastSpeed {
            accumulate(&current, from: previous, to: (kmh, now))
        }
        current.lastSpeed = (kmh, now)
        current.lastUpdate = max(current.lastUpdate, now)
        record(reading, into: &current)

        if kmh >= settings.stoppedKmh {
            current.stoppedSince = nil
            current.lastMovingAt = now
        } else if current.stoppedSince == nil {
            current.stoppedSince = now
        }

        if let since = current.stoppedSince, now.timeIntervalSince(since) >= settings.endAfterStopped {
            active = nil
            lastSeenSpeed = nil
            return build(current, endedAt: current.lastMovingAt)
        }
        active = current
        return nil
    }

    /// Adds the distance and moving time between two speed readings (trapezoid rule).
    private func accumulate(_ trip: inout Active, from previous: (kmh: Double, at: Date), to next: (kmh: Double, at: Date)) {
        let dt = next.at.timeIntervalSince(previous.at)
        guard dt > 0, dt <= settings.maxGap else { return }
        trip.distanceKm += (previous.kmh + next.kmh) / 2 * dt / 3600
        if max(previous.kmh, next.kmh) >= settings.stoppedKmh { trip.movingSeconds += dt }
    }

    private func record(_ reading: OBDReading, into trip: inout Active) {
        switch reading.pid {
        case .speed: trip.maxSpeedKmh = max(trip.maxSpeedKmh, reading.value)
        case .rpm: trip.maxRPM = max(trip.maxRPM ?? reading.value, reading.value)
        case .coolantTemperature: trip.maxCoolant = max(trip.maxCoolant ?? reading.value, reading.value)
        case .fuelLevel:
            if trip.firstFuel == nil { trip.firstFuel = reading.value }
            trip.lastFuel = reading.value
        default: break
        }

        let due = trip.lastSampleAt[reading.pid].map { reading.timestamp.timeIntervalSince($0) >= settings.sampleInterval } ?? true
        if due {
            trip.lastSampleAt[reading.pid] = reading.timestamp
            trip.samples.append(TripSample(pid: Int(reading.pid.rawValue), value: reading.value, recordedAt: reading.timestamp))
        }
    }

    private func build(_ trip: Active, endedAt: Date) -> RecordedTrip? {
        let miles = trip.distanceKm / kilometersPerMile
        guard miles >= settings.minDistanceMiles else { return nil }

        let avgSpeed = trip.movingSeconds > 0 ? miles / (trip.movingSeconds / 3600) : nil
        var fuelUsed: Double?
        if let first = trip.firstFuel, let last = trip.lastFuel, last <= first {
            fuelUsed = first - last
        }
        return RecordedTrip(
            id: UUID(), vehicleID: vehicleID, startedAt: trip.startedAt, endedAt: max(endedAt, trip.startedAt),
            distanceMiles: miles, avgSpeedMph: avgSpeed, maxSpeedMph: trip.maxSpeedKmh / kilometersPerMile,
            maxRPM: trip.maxRPM, maxCoolantC: trip.maxCoolant, fuelUsedPercent: fuelUsed,
            samples: trip.samples
        )
    }
}
