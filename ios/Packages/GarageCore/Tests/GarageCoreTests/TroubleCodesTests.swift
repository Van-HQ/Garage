import XCTest
@testable import GarageCore

final class TroubleCodesTests: XCTestCase {
    func testKnownCode() {
        let info = TroubleCodes.info(for: "p0456")
        XCTAssertEqual(info.code, "P0456")
        XCTAssertEqual(info.title, "EVAP system: very small leak")
        XCTAssertTrue(info.isKnown)
    }

    func testCylinderMisfiresAreGenerated() {
        XCTAssertEqual(TroubleCodes.info(for: "P0304").title, "Cylinder 4 misfire")
        XCTAssertTrue(TroubleCodes.info(for: "P0304").isKnown)
        // P0300 is the "random misfire" entry, not "cylinder 0".
        XCTAssertEqual(TroubleCodes.info(for: "P0300").title, "Random or multiple cylinder misfire")
        // P0325 starts with P03 too but is the knock sensor.
        XCTAssertEqual(TroubleCodes.info(for: "P0325").title, "Knock sensor 1 circuit")
    }

    func testUnknownCodesDescribeTheFamilyOnly() {
        let generic = TroubleCodes.info(for: "C0999")
        XCTAssertFalse(generic.isKnown)
        XCTAssertEqual(generic.title, "Chassis code")
        XCTAssertTrue(generic.explanation.contains("C0999"))

        let makerSpecific = TroubleCodes.info(for: "P1604")
        XCTAssertFalse(makerSpecific.isKnown)
        XCTAssertTrue(makerSpecific.explanation.contains("manufacturer-specific"))
    }
}
