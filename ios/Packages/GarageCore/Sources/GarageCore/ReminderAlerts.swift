import Foundation

/// Decides when a maintenance item deserves a pop-up: the moment it turns overdue,
/// not every time CarPlay connects while it stays overdue.
public enum ReminderAlerts {
    /// Remembered status per maintenance type, as saved between runs.
    public typealias Memory = [String: String]

    public static func memory(of statuses: [MaintenanceStatusItem]) -> Memory {
        Dictionary(uniqueKeysWithValues: statuses.map { ($0.id.uuidString, $0.status.rawValue) })
    }

    /// Names of items that are overdue now but weren't last time. With no memory yet
    /// (first run), nothing is "new": the current state just becomes the baseline.
    public static func newlyOverdue(_ statuses: [MaintenanceStatusItem], previous: Memory?) -> [String] {
        guard let previous else { return [] }
        return statuses
            .filter { $0.status == .overdue && previous[$0.id.uuidString] != DueStatus.overdue.rawValue }
            .map(\.type.name)
    }

    /// "Oil & Filter Change is overdue." or "Oil & Filter Change and 2 more are overdue."
    public static func message(for names: [String]) -> String {
        switch names.count {
        case 0: ""
        case 1: "\(names[0]) is overdue."
        default: "\(names[0]) and \(names.count - 1) more are overdue."
        }
    }
}
