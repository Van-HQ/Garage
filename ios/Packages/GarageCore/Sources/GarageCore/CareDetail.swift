import Foundation

// Port of src/lib/care-detail.ts.

/// Every log of one maintenance type for one vehicle, newest first.
public func historyForType(logs: [MaintenanceLog], vehicle: Vehicle, type: MaintenanceType) -> [MaintenanceLog] {
    logs
        .filter { $0.vehicleID == vehicle.id && $0.maintenanceTypeID == type.id }
        .stableSorted { $0.performedAt > $1.performedAt }
}

public struct IntervalAverage: Hashable, Sendable {
    public let avgMiles: Int?
    public let avgDays: Int?
    /// Positive means servicing more often than the target interval (ahead of schedule).
    public let percentAheadMiles: Int?
}

/// Average gap between consecutive logs of this type. Needs at least 2 logs.
public func computeIntervalAverage(history: [MaintenanceLog], type: MaintenanceType) -> IntervalAverage {
    guard history.count >= 2 else { return IntervalAverage(avgMiles: nil, avgDays: nil, percentAheadMiles: nil) }

    let chronological = history.stableSorted { $0.performedAt < $1.performedAt }
    let first = chronological[0]
    let last = chronological[chronological.count - 1]
    let gaps = Double(chronological.count - 1)

    let avgMiles = Double(last.mileageAt - first.mileageAt) / gaps
    let avgDays = last.performedAt.timeIntervalSince(first.performedAt) / gaps / secondsPerDay

    var percentAhead: Int?
    if let interval = type.intervalMiles, interval > 0 {
        percentAhead = jsRound((Double(interval) - avgMiles) / Double(interval) * 100)
    }

    return IntervalAverage(avgMiles: jsRound(avgMiles), avgDays: jsRound(avgDays), percentAheadMiles: percentAhead)
}

public func totalCost(_ history: [MaintenanceLog]) -> Double {
    history.reduce(0) { $0 + ($1.cost ?? 0) }
}
