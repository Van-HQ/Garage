import Foundation

// Port of src/lib/mileage-trend.ts.

public struct TrendPoint: Hashable, Sendable {
    public enum Kind: Sendable { case maintenance, checkin }

    public let date: Date
    public let mileage: Int
    public let kind: Kind
    /// The log's title for maintenance points; nil for odometer check-ins.
    public let label: String?

    public init(date: Date, mileage: Int, kind: Kind, label: String? = nil) {
        self.date = date; self.mileage = mileage; self.kind = kind; self.label = label
    }
}

/// Chronological odometer readings for a vehicle, drawn from every logged source.
public func computeMileageTrend(
    vehicle: Vehicle,
    logs: [MaintenanceLog],
    mileageLogs: [MileageLog]
) -> [TrendPoint] {
    var points: [TrendPoint] = []
    for log in logs where log.vehicleID == vehicle.id {
        points.append(TrendPoint(date: log.performedAt, mileage: log.mileageAt, kind: .maintenance, label: log.title))
    }
    for log in mileageLogs where log.vehicleID == vehicle.id {
        points.append(TrendPoint(date: log.recordedAt, mileage: log.mileage, kind: .checkin))
    }
    return points.stableSorted { $0.date < $1.date }
}

public struct MonthlyMiles: Hashable, Sendable {
    public let year: Int
    /// 1 through 12.
    public let month: Int
    public let miles: Int

    public init(year: Int, month: Int, miles: Int) {
        self.year = year; self.month = month; self.miles = miles
    }
}

/// Miles driven per calendar month. Each stretch between two consecutive
/// readings is credited to the month its midpoint falls in, so a reading taken
/// on Aug 1 closes out July rather than starting August. Months with no
/// stretch landing in them are absent rather than estimated.
public func computeMonthlyMiles(
    _ points: [TrendPoint],
    limit: Int = 6,
    calendar: Calendar = .current
) -> [MonthlyMiles] {
    guard points.count >= 2 else { return [] }

    // Points are chronological, so midpoints are too and months come out in order.
    var order: [DateComponents] = []
    var milesByMonth: [DateComponents: Int] = [:]
    for (from, to) in zip(points, points.dropFirst()) {
        let mid = Date(timeIntervalSince1970: (from.date.timeIntervalSince1970 + to.date.timeIntervalSince1970) / 2)
        let key = calendar.dateComponents([.year, .month], from: mid)
        if milesByMonth[key] == nil { order.append(key) }
        milesByMonth[key, default: 0] += max(0, to.mileage - from.mileage)
    }

    return order
        .map { MonthlyMiles(year: $0.year ?? 0, month: $0.month ?? 1, miles: milesByMonth[$0] ?? 0) }
        .suffix(limit)
        .map { $0 }
}

public struct MonthlyStat: Hashable, Sendable {
    public let month: MonthlyMiles
    /// Miles driven minus the previous month's miles; nil for the first month on record.
    public let changeMiles: Int?
    /// changeMiles as a percent of the previous month's miles; nil when there is no (or a zero) previous month.
    public let changePercent: Int?
}

/// Monthly miles with month-over-month change, newest month first.
public func computeMonthlyStats(
    _ points: [TrendPoint],
    limit: Int = 6,
    calendar: Calendar = .current
) -> [MonthlyStat] {
    let all = computeMonthlyMiles(points, limit: .max, calendar: calendar)
    let stats = all.enumerated().map { index, month -> MonthlyStat in
        guard index > 0 else { return MonthlyStat(month: month, changeMiles: nil, changePercent: nil) }
        let previous = all[index - 1]
        let change = month.miles - previous.miles
        let percent = previous.miles > 0 ? jsRound(Double(change) / Double(previous.miles) * 100) : nil
        return MonthlyStat(month: month, changeMiles: change, changePercent: percent)
    }
    return Array(stats.suffix(limit).reversed())
}

/// The service points that get an icon on the Home chart: newest first, skipping any too close in time
/// to one already picked (as a share of the whole chart), so icons never sit on top of each other.
public func spacedServiceMarkers(_ points: [TrendPoint], minimumGap: Double = 0.1, limit: Int = 4) -> [TrendPoint] {
    guard let first = points.map(\.date).min(), let last = points.map(\.date).max() else { return [] }
    let span = max(last.timeIntervalSince(first), 1)
    var picked: [TrendPoint] = []
    for point in points.filter({ $0.kind == .maintenance }).sorted(by: { $0.date > $1.date }) {
        guard picked.count < limit else { break }
        if picked.allSatisfy({ abs($0.date.timeIntervalSince(point.date)) / span >= minimumGap }) {
            picked.append(point)
        }
    }
    return picked.reversed()
}
