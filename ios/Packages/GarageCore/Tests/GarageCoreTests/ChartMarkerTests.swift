import XCTest
@testable import GarageCore

final class ChartMarkerTests: XCTestCase {
    private func point(_ day: Double, _ kind: TrendPoint.Kind = .maintenance) -> TrendPoint {
        TrendPoint(date: Date(timeIntervalSince1970: day * 86_400), mileage: Int(day), kind: kind)
    }

    func testCrowdedServicesKeepOnlyTheNewestOfEachCluster() {
        let points = [point(0, .checkin), point(50), point(52), point(52), point(98), point(100)]
        XCTAssertEqual(spacedServiceMarkers(points).map(\.mileage), [52, 100])
    }

    func testNeverMoreThanTheLimitAndAlwaysSpaced() {
        let points = (0...100).map { point(Double($0)) }
        let picked = spacedServiceMarkers(points)
        XCTAssertEqual(picked.count, 4)
        for (a, b) in zip(picked, picked.dropFirst()) { XCTAssertGreaterThanOrEqual(b.mileage - a.mileage, 10) }
    }

    func testCheckInsGetNoIcon() {
        XCTAssertTrue(spacedServiceMarkers([point(0, .checkin), point(10, .checkin)]).isEmpty)
    }
}
