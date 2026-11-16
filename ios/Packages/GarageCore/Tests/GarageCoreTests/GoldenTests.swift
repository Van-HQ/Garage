import XCTest
@testable import GarageCore

/// Checks the Swift ports against the web app's own output. golden.json is
/// produced by ios/tools/gen-core-golden.mjs, which runs the real src/lib
/// functions on a fixed data set.
final class GoldenTests: XCTestCase {
    struct Golden: Decodable {
        let now: Date
        let vehicles: [Vehicle]
        let types: [MaintenanceType]
        let logs: [MaintenanceLog]
        let mileageLogs: [MileageLog]
        let expected: [String: Expected]
    }

    struct Expected: Decodable {
        let projectedMileage: Int
        let status: [Status]
        let trend: [Trend]
        let monthlyMiles: [Month]
        let monthlyMilesAll: [Month]
        let monthlyStats: [MonthStat]
        let careDetail: [Care]
    }

    struct Status: Decodable {
        let typeId: UUID
        let lastLogId: UUID?
        let dueMileage: Int?
        let dueDate: Date?
        let milesRemaining: Int?
        let daysRemaining: Int?
        let status: String
    }

    struct Trend: Decodable {
        let date: Date
        let mileage: Int
        let kind: String
        let label: String?
    }

    struct Month: Decodable, Equatable {
        let fullLabel: String
        let miles: Int
    }

    struct MonthStat: Decodable {
        let fullLabel: String
        let miles: Int
        let changeMiles: Int?
        let changePct: Int?
    }

    struct Care: Decodable {
        struct Average: Decodable {
            let avgMiles: Int?
            let avgDays: Int?
            let percentAheadMiles: Int?
        }
        let typeId: UUID
        let historyIds: [UUID]
        let average: Average
        let totalCost: Double
    }

    /// The generator pins this zone, because months are bucketed in local time.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    static let golden: Golden = {
        let url = Bundle.module.url(forResource: "golden", withExtension: "json", subdirectory: "Fixtures")!
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = formatter.date(from: text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
            }
            return date
        }
        return try! decoder.decode(Golden.self, from: Data(contentsOf: url))
    }()

    private func fullLabel(_ month: MonthlyMiles) -> String {
        let date = Self.calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1))!
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar
        formatter.timeZone = Self.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func forEachVehicle(_ body: (Vehicle, Expected, Golden) -> Void) {
        let golden = Self.golden
        XCTAssertFalse(golden.vehicles.isEmpty)
        for vehicle in golden.vehicles {
            guard let expected = golden.expected[vehicle.id.uuidString.lowercased()] else {
                return XCTFail("No expected block for \(vehicle.name)")
            }
            body(vehicle, expected, golden)
        }
    }

    func testProjectedMileage() {
        forEachVehicle { vehicle, expected, golden in
            XCTAssertEqual(projectedMileage(vehicle, now: golden.now), expected.projectedMileage, vehicle.name)
        }
    }

    func testMaintenanceStatus() {
        forEachVehicle { vehicle, expected, golden in
            let items = computeMaintenanceStatus(vehicle: vehicle, types: golden.types, logs: golden.logs, now: golden.now)
            XCTAssertEqual(items.count, expected.status.count, vehicle.name)
            for (item, want) in zip(items, expected.status) {
                let name = "\(vehicle.name) / \(item.type.name)"
                XCTAssertEqual(item.type.id, want.typeId, "order: \(name)")
                XCTAssertEqual(item.lastLog?.id, want.lastLogId, name)
                XCTAssertEqual(item.dueMileage, want.dueMileage, name)
                XCTAssertEqual(item.dueDate, want.dueDate, name)
                XCTAssertEqual(item.milesRemaining, want.milesRemaining, name)
                XCTAssertEqual(item.daysRemaining, want.daysRemaining, name)
                XCTAssertEqual(item.status.rawValue, want.status, name)
            }
        }
    }

    func testMileageTrend() {
        forEachVehicle { vehicle, expected, golden in
            let trend = computeMileageTrend(vehicle: vehicle, logs: golden.logs, mileageLogs: golden.mileageLogs)
            XCTAssertEqual(trend.count, expected.trend.count, vehicle.name)
            for (point, want) in zip(trend, expected.trend) {
                XCTAssertEqual(point.date, want.date)
                XCTAssertEqual(point.mileage, want.mileage)
                XCTAssertEqual(point.kind == .maintenance ? "maintenance" : "checkin", want.kind)
                XCTAssertEqual(point.label, want.label)
            }
        }
    }

    func testMonthlyMiles() {
        forEachVehicle { vehicle, expected, golden in
            let trend = computeMileageTrend(vehicle: vehicle, logs: golden.logs, mileageLogs: golden.mileageLogs)
            let recent = computeMonthlyMiles(trend, calendar: Self.calendar)
            XCTAssertEqual(recent.map { Month(fullLabel: fullLabel($0), miles: $0.miles) }, expected.monthlyMiles, vehicle.name)
            let all = computeMonthlyMiles(trend, limit: 1000, calendar: Self.calendar)
            XCTAssertEqual(all.map { Month(fullLabel: fullLabel($0), miles: $0.miles) }, expected.monthlyMilesAll, vehicle.name)
        }
    }

    func testMonthlyStats() {
        forEachVehicle { vehicle, expected, golden in
            let trend = computeMileageTrend(vehicle: vehicle, logs: golden.logs, mileageLogs: golden.mileageLogs)
            let stats = computeMonthlyStats(trend, calendar: Self.calendar)
            XCTAssertEqual(stats.count, expected.monthlyStats.count, vehicle.name)
            for (stat, want) in zip(stats, expected.monthlyStats) {
                XCTAssertEqual(fullLabel(stat.month), want.fullLabel)
                XCTAssertEqual(stat.month.miles, want.miles, want.fullLabel)
                XCTAssertEqual(stat.changeMiles, want.changeMiles, want.fullLabel)
                XCTAssertEqual(stat.changePercent, want.changePct, want.fullLabel)
            }
        }
    }

    func testCareDetail() {
        forEachVehicle { vehicle, expected, golden in
            for want in expected.careDetail {
                let type = golden.types.first { $0.id == want.typeId }!
                let history = historyForType(logs: golden.logs, vehicle: vehicle, type: type)
                let name = "\(vehicle.name) / \(type.name)"
                XCTAssertEqual(history.map(\.id), want.historyIds, name)
                let average = computeIntervalAverage(history: history, type: type)
                XCTAssertEqual(average.avgMiles, want.average.avgMiles, name)
                XCTAssertEqual(average.avgDays, want.average.avgDays, name)
                XCTAssertEqual(average.percentAheadMiles, want.average.percentAheadMiles, name)
                XCTAssertEqual(totalCost(history), want.totalCost, accuracy: 0.0001, name)
            }
        }
    }
}
