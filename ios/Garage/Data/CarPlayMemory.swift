import Foundation
import GarageCore

/// Small things CarPlay remembers between connections, so it can show each thing once.
enum CarPlayMemory {
    private static let defaults = UserDefaults.standard
    private static let summaryKey = "carplay.lastTripSummary"
    private static let shownKey = "carplay.shownTripID"

    // MARK: Trip summary

    /// Saved when a trip finishes. The drive usually ends with the engine off, after
    /// CarPlay has already gone, so the summary waits for the next connection.
    static func saveSummary(_ summary: TripSummary) {
        defaults.set(try? JSONEncoder().encode(summary), forKey: summaryKey)
    }

    /// The saved summary if it should be shown now: recent, and not shown before.
    static func summaryToShow(now: Date = Date()) -> TripSummary? {
        guard let data = defaults.data(forKey: summaryKey),
              let summary = try? JSONDecoder().decode(TripSummary.self, from: data) else { return nil }
        let shown = defaults.string(forKey: shownKey).flatMap(UUID.init(uuidString:))
        return TripSummaryRules.shouldShow(summary, alreadyShown: shown, now: now) ? summary : nil
    }

    static func markShown(_ summary: TripSummary) {
        defaults.set(summary.tripID.uuidString, forKey: shownKey)
    }

    // MARK: Maintenance reminders

    private static func reminderKey(_ vehicleID: UUID) -> String { "carplay.reminderStatus.\(vehicleID.uuidString)" }

    static func reminderMemory(for vehicleID: UUID) -> ReminderAlerts.Memory? {
        defaults.dictionary(forKey: reminderKey(vehicleID)) as? ReminderAlerts.Memory
    }

    static func saveReminderMemory(_ memory: ReminderAlerts.Memory, for vehicleID: UUID) {
        defaults.set(memory, forKey: reminderKey(vehicleID))
    }
}
