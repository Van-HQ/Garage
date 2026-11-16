import XCTest
@testable import GarageCore

/// cost.ts imports a runtime value through the web app's "@/" path alias, so
/// the golden generator can't run it under plain Node. These expectations were
/// worked out by hand from the same fixture data.
final class CostBreakdownTests: XCTestCase {
    func testBuddyBreakdown() {
        let golden = GoldenTests.golden
        let buddy = golden.vehicles[0]
        let result = computeCostBreakdown(
            vehicleID: buddy.id, logs: golden.logs, types: golden.types,
            now: golden.now, calendar: GoldenTests.calendar
        )

        // Oil 74.5 + 82 + 0, tires 25, wash 18 (one wash has no cost), lift kit 1899.99, untyped chip repair 60.
        XCTAssertEqual(result.total, 2159.49, accuracy: 0.0001)
        // Everything except the $0 oil change on 2025-10-20 happened in 2026.
        XCTAssertEqual(result.thisYearTotal, 2159.49, accuracy: 0.0001)
        XCTAssertEqual(result.byCategory.map(\.category), [.upgrade, .oil, .custom, .tires, .wash])
        XCTAssertEqual(result.byCategory.map(\.amount), [1899.99, 156.5, 60, 25, 18])
    }

    func testOnlyCountsTheRequestedVehicleAndYear() {
        let golden = GoldenTests.golden
        let rav4 = golden.vehicles[1]
        let result = computeCostBreakdown(
            vehicleID: rav4.id, logs: golden.logs, types: golden.types,
            now: golden.now, calendar: GoldenTests.calendar
        )
        XCTAssertEqual(result.total, 225, accuracy: 0.0001)
        // The brake fluid job was in 2024.
        XCTAssertEqual(result.thisYearTotal, 85, accuracy: 0.0001)
        XCTAssertEqual(result.byCategory.map(\.category), [.custom, .oil, .wash])
    }

    func testNoCostsGivesAnEmptyBreakdown() {
        let result = computeCostBreakdown(vehicleID: UUID(), logs: [], types: [])
        XCTAssertEqual(result.total, 0)
        XCTAssertTrue(result.byCategory.isEmpty)
    }
}
