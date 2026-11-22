import XCTest
@testable import GarageCore

final class TripSummaryTests: XCTestCase {
    private func trip(endedAt: Date, miles: Double = 12.4, minutes: Double = 28) -> RecordedTrip {
        RecordedTrip(
            id: UUID(), vehicleID: UUID(), startedAt: endedAt.addingTimeInterval(-minutes * 60), endedAt: endedAt,
            distanceMiles: miles, avgSpeedMph: 26.6, maxSpeedMph: 61.2, maxRPM: nil, maxCoolantC: nil,
            fuelUsedPercent: 6, samples: []
        )
    }

    func testMessageReadsNaturally() {
        let summary = TripSummary(trip: trip(endedAt: Date()), vehicleName: "Buddy")
        XCTAssertEqual(summary.headline, "12.4 mi in 28 min")
        XCTAssertEqual(summary.message, "Buddy: 12.4 mi in 28 min. Avg 27 mph, max 61 mph, 6% fuel")
    }

    func testLongTripShowsHours() {
        let summary = TripSummary(trip: trip(endedAt: Date(), minutes: 95), vehicleName: "Buddy")
        XCTAssertTrue(summary.headline.hasSuffix("1 h 35 min"))
    }

    func testShowsOnceAndOnlyWhenRecent() {
        let now = Date()
        let fresh = TripSummary(trip: trip(endedAt: now.addingTimeInterval(-600)), vehicleName: "Buddy")
        XCTAssertTrue(TripSummaryRules.shouldShow(fresh, alreadyShown: nil, now: now))
        XCTAssertFalse(TripSummaryRules.shouldShow(fresh, alreadyShown: fresh.tripID, now: now))

        let stale = TripSummary(trip: trip(endedAt: now.addingTimeInterval(-13 * 3600)), vehicleName: "Buddy")
        XCTAssertFalse(TripSummaryRules.shouldShow(stale, alreadyShown: nil, now: now))
    }
}

final class ReminderAlertsTests: XCTestCase {
    private let user = UUID()

    private func item(_ name: String, _ status: DueStatus, id: UUID = UUID()) -> MaintenanceStatusItem {
        MaintenanceStatusItem(
            type: MaintenanceType(id: id, userID: user, name: name, createdAt: Date()),
            lastLog: nil, dueMileage: nil, dueDate: nil, milesRemaining: nil, daysRemaining: nil, status: status
        )
    }

    func testFirstRunOnlySetsABaseline() {
        let items = [item("Oil change", .overdue)]
        XCTAssertTrue(ReminderAlerts.newlyOverdue(items, previous: nil).isEmpty)
    }

    func testAlertsOnlyOnTheTransitionToOverdue() {
        let id = UUID()
        let before = ReminderAlerts.memory(of: [item("Oil change", .dueSoon, id: id)])
        let now = [item("Oil change", .overdue, id: id)]
        XCTAssertEqual(ReminderAlerts.newlyOverdue(now, previous: before), ["Oil change"])

        // Next connect: it was already overdue, so no repeat.
        XCTAssertTrue(ReminderAlerts.newlyOverdue(now, previous: ReminderAlerts.memory(of: now)).isEmpty)
    }

    func testBrandNewItemThatIsOverdueAlerts() {
        let before = ReminderAlerts.memory(of: [item("Tire rotation", .ok)])
        XCTAssertEqual(ReminderAlerts.newlyOverdue([item("Wipers", .overdue)], previous: before), ["Wipers"])
    }

    func testMessageGroupsSeveral() {
        XCTAssertEqual(ReminderAlerts.message(for: ["Oil"]), "Oil is overdue.")
        XCTAssertEqual(ReminderAlerts.message(for: ["Oil", "Brakes", "Wipers"]), "Oil and 2 more are overdue.")
    }
}

final class TripSummaryFuelTests: XCTestCase {
    func testTinyFuelUseIsLeftOut() {
        let end = Date()
        let trip = RecordedTrip(
            id: UUID(), vehicleID: UUID(), startedAt: end.addingTimeInterval(-90), endedAt: end, distanceMiles: 0.4,
            avgSpeedMph: 35, maxSpeedMph: 42, maxRPM: nil, maxCoolantC: nil, fuelUsedPercent: 0.2, samples: []
        )
        XCTAssertFalse(TripSummary(trip: trip, vehicleName: "Buddy").message.contains("fuel"))
    }
}
