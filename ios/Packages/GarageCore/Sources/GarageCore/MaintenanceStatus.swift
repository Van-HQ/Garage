import Foundation

// Port of src/lib/maintenance-status.ts.

/// Projects today's mileage forward from the last known odometer reading,
/// using the vehicle's average daily miles.
public func projectedMileage(_ vehicle: Vehicle, now: Date = Date()) -> Int {
    let daysSince = max(0, now.timeIntervalSince(vehicle.mileageUpdatedAt) / secondsPerDay)
    return jsRound(Double(vehicle.currentMileage) + daysSince * vehicle.avgDailyMiles)
}

public enum DueStatus: String, Sendable, CaseIterable {
    case overdue
    case dueSoon = "due-soon"
    case ok
    case unscheduled

    /// Sort order on screen: overdue first, unscheduled last.
    var rank: Int {
        switch self {
        case .overdue: 0
        case .dueSoon: 1
        case .ok: 2
        case .unscheduled: 3
        }
    }
}

public struct MaintenanceStatusItem: Identifiable, Hashable, Sendable {
    public let type: MaintenanceType
    public let lastLog: MaintenanceLog?
    public let dueMileage: Int?
    public let dueDate: Date?
    public let milesRemaining: Int?
    public let daysRemaining: Int?
    public let status: DueStatus

    public var id: UUID { type.id }
}

/// "Due soon" triggers inside this many miles or days of the threshold.
public let dueSoonMiles = 500
public let dueSoonDays = 14

public func computeMaintenanceStatus(
    vehicle: Vehicle,
    types: [MaintenanceType],
    logs: [MaintenanceLog],
    now: Date = Date()
) -> [MaintenanceStatusItem] {
    let projected = projectedMileage(vehicle, now: now)

    return types
        .filter { $0.vehicleID == nil || $0.vehicleID == vehicle.id }
        .map { type -> MaintenanceStatusItem in
            let lastLog = logs
                .filter { $0.maintenanceTypeID == type.id && $0.vehicleID == vehicle.id }
                .stableSorted { $0.performedAt > $1.performedAt }
                .first

            let baseMileage = lastLog?.mileageAt ?? type.baselineMileage ?? 0
            let baseDate = lastLog?.performedAt ?? type.baselineDate ?? vehicle.createdAt

            let dueMileage = type.intervalMiles.map { baseMileage + $0 }
            let dueDate = type.intervalDays.map { baseDate.addingTimeInterval(Double($0) * secondsPerDay) }

            let milesRemaining = dueMileage.map { $0 - projected }
            let daysRemaining = dueDate.map { jsRound($0.timeIntervalSince(now) / secondsPerDay) }

            let status: DueStatus
            if milesRemaining == nil && daysRemaining == nil {
                status = lastLog != nil ? .ok : .unscheduled
            } else {
                let overdue = (milesRemaining.map { $0 <= 0 } ?? false) || (daysRemaining.map { $0 <= 0 } ?? false)
                let soon = (milesRemaining.map { $0 <= dueSoonMiles } ?? false)
                    || (daysRemaining.map { $0 <= dueSoonDays } ?? false)
                status = overdue ? .overdue : soon ? .dueSoon : .ok
            }

            return MaintenanceStatusItem(
                type: type, lastLog: lastLog, dueMileage: dueMileage, dueDate: dueDate,
                milesRemaining: milesRemaining, daysRemaining: daysRemaining, status: status
            )
        }
        .stableSorted { $0.status.rank < $1.status.rank }
}
