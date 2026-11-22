import XCTest
@testable import GarageCore

final class DriveAlertsTests: XCTestCase {
    func testNormalCoolantDoesNotAlert() {
        let result = DriveAlerts.coolant(celsius: 92, wasHot: false)
        XCTAssertFalse(result.isHot)
        XCTAssertNil(result.alert)
    }

    func testCrossingTheLimitAlertsOnce() {
        let first = DriveAlerts.coolant(celsius: 112, wasHot: false)
        XCTAssertTrue(first.isHot)
        XCTAssertEqual(first.alert?.kind, .coolantHot)
        XCTAssertTrue(first.alert?.message.contains("234 °F") ?? false)

        let second = DriveAlerts.coolant(celsius: 114, wasHot: first.isHot)
        XCTAssertTrue(second.isHot)
        XCTAssertNil(second.alert)
    }

    func testDippingJustBelowTheLimitDoesNotRearm() {
        let still = DriveAlerts.coolant(celsius: 108, wasHot: true)
        XCTAssertTrue(still.isHot)
        XCTAssertNil(still.alert)
    }

    func testRecoveringThenOverheatingAgainAlertsAgain() {
        let cooled = DriveAlerts.coolant(celsius: 100, wasHot: true)
        XCTAssertFalse(cooled.isHot)
        XCTAssertNotNil(DriveAlerts.coolant(celsius: 111, wasHot: cooled.isHot).alert)
    }

    func testOnlyNewCodesAlert() {
        let alerts = DriveAlerts.newCodes(previous: ["P0456"], current: ["P0456", "P0301"])
        XCTAssertEqual(alerts.map(\.id), ["code-P0301"])
        XCTAssertEqual(alerts.first?.kind, .checkEngine)
        XCTAssertTrue(alerts.first?.message.hasPrefix("P0301") ?? false)
    }

    func testNoCodesNoAlerts() {
        XCTAssertTrue(DriveAlerts.newCodes(previous: [], current: []).isEmpty)
    }
}
