import Foundation

// Port of src/lib/cost.ts.

public struct CostBreakdown: Hashable, Sendable {
    public struct CategoryAmount: Hashable, Sendable {
        public let category: MaintenanceCategory
        public let amount: Double
    }

    public let total: Double
    public let thisYearTotal: Double
    /// Largest amount first.
    public let byCategory: [CategoryAmount]
}

public func computeCostBreakdown(
    vehicleID: UUID,
    logs: [MaintenanceLog],
    types: [MaintenanceType],
    now: Date = Date(),
    calendar: Calendar = .current
) -> CostBreakdown {
    let typeByID = Dictionary(types.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let currentYear = calendar.component(.year, from: now)

    var total = 0.0
    var thisYearTotal = 0.0
    var order: [MaintenanceCategory] = []
    var amounts: [MaintenanceCategory: Double] = [:]

    for log in logs where log.vehicleID == vehicleID {
        guard let amount = log.cost else { continue }
        total += amount
        if calendar.component(.year, from: log.performedAt) == currentYear { thisYearTotal += amount }

        // A log whose type was deleted counts as "custom", as on the web.
        let category = log.maintenanceTypeID.flatMap { typeByID[$0] }?.category ?? .custom
        if amounts[category] == nil { order.append(category) }
        amounts[category, default: 0] += amount
    }

    let byCategory = order
        .map { CostBreakdown.CategoryAmount(category: $0, amount: amounts[$0] ?? 0) }
        .stableSorted { $0.amount > $1.amount }

    return CostBreakdown(total: total, thisYearTotal: thisYearTotal, byCategory: byCategory)
}
