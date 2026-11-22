import Foundation

/// A short recap of a finished drive, shown on CarPlay.
public struct TripSummary: Codable, Equatable, Sendable {
    public let tripID: UUID
    public let vehicleName: String
    public let endedAt: Date
    public let distanceMiles: Double
    public let duration: TimeInterval
    public let avgSpeedMph: Double?
    public let maxSpeedMph: Double?
    public let fuelUsedPercent: Double?

    public init(trip: RecordedTrip, vehicleName: String) {
        self.tripID = trip.id
        self.vehicleName = vehicleName
        self.endedAt = trip.endedAt
        self.distanceMiles = trip.distanceMiles
        self.duration = trip.duration
        self.avgSpeedMph = trip.avgSpeedMph
        self.maxSpeedMph = trip.maxSpeedMph
        self.fuelUsedPercent = trip.fuelUsedPercent
    }

    /// "Trip complete".
    public var title: String { "Trip complete" }

    /// "12.4 mi in 28 min".
    public var headline: String {
        let miles = String(format: "%.1f", distanceMiles)
        let minutes = max(1, Int((duration / 60).rounded()))
        let time = minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
        return "\(miles) mi in \(time)"
    }

    /// The full line for the alert: "Buddy: 12.4 mi in 28 min. Avg 27 mph, max 61 mph, 6% fuel."
    public var message: String {
        var extras: [String] = []
        if let avg = avgSpeedMph { extras.append("avg \(Int(avg.rounded())) mph") }
        if let top = maxSpeedMph { extras.append("max \(Int(top.rounded())) mph") }
        if let fuel = fuelUsedPercent, fuel.rounded() >= 1 { extras.append("\(Int(fuel.rounded()))% fuel") }
        var tail = extras.joined(separator: ", ")
        if let first = tail.first { tail = ". " + first.uppercased() + tail.dropFirst() }
        return "\(vehicleName): \(headline)\(tail)"
    }
}

public enum TripSummaryRules {
    /// A summary shows once, and only while it is recent. A trip from last week isn't news.
    public static let maxAge: TimeInterval = 12 * 3600

    public static func shouldShow(_ summary: TripSummary, alreadyShown: UUID?, now: Date = Date()) -> Bool {
        guard summary.tripID != alreadyShown else { return false }
        let age = now.timeIntervalSince(summary.endedAt)
        return age >= 0 && age <= maxAge
    }
}
