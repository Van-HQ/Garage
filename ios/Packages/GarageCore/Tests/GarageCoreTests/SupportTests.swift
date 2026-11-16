import XCTest
@testable import GarageCore

final class SupportTests: XCTestCase {
    func testJsRoundMatchesMathRound() {
        XCTAssertEqual(jsRound(2.5), 3)
        XCTAssertEqual(jsRound(-2.5), -2)
        XCTAssertEqual(jsRound(-2.51), -3)
        XCTAssertEqual(jsRound(0.49), 0)
        XCTAssertEqual(jsRound(-0.5), 0)
    }

    func testStableSortedKeepsEqualElementsInOrder() {
        let pairs = [(1, "a"), (0, "b"), (1, "c"), (0, "d"), (1, "e")]
        XCTAssertEqual(pairs.stableSorted { $0.0 < $1.0 }.map(\.1), ["b", "d", "a", "c", "e"])
    }

    func testUnknownCategoryDecodesAsCustom() throws {
        let decoded = try JSONDecoder().decode([MaintenanceCategory].self, from: Data(#"["oil","detailing"]"#.utf8))
        XCTAssertEqual(decoded, [.oil, .custom])
    }
}
