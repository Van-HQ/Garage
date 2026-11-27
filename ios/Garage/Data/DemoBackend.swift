import Foundation
import GarageCore
import UIKit

#if DEBUG
/// Sample data that lives in memory, for SwiftUI previews and `-demo` launches.
/// Lets every screen be exercised with no account and no network.
actor DemoBackend: GarageBackend {
    private var snapshot: GarageSnapshot
    private var trips: [Trip] = []
    /// Starts with one open code so the Care banner can be seen in demo mode.
    private var demoCodes: [OpenTroubleCode] = []

    init(now: Date = Date()) {
        snapshot = DemoData.snapshot(now: now)
        if let first = snapshot.vehicles.first { demoCodes = [OpenTroubleCode(vehicleID: first.id, code: "P0456")] }
    }

    func loadSnapshot() async throws -> GarageSnapshot { snapshot }

    func logMaintenance(_ draft: MaintenanceDraft, photos: [Data]) async throws -> Int {
        let log = MaintenanceLog(
            id: UUID(), userID: DemoData.userID, vehicleID: draft.vehicleID, maintenanceTypeID: draft.typeID,
            title: draft.title, notes: draft.notes, cost: draft.cost, mileageAt: draft.mileage,
            performedAt: draft.performedAt
        )
        snapshot.logs.append(log)
        snapshot.logs.sort { $0.performedAt > $1.performedAt }
        recomputeMileage(for: draft.vehicleID)
        return 0
    }

    func logMileage(_ draft: MileageDraft) async throws {
        let reading = MileageLog(
            id: UUID(), userID: DemoData.userID, vehicleID: draft.vehicleID, mileage: draft.mileage,
            note: draft.note, recordedAt: draft.recordedAt
        )
        snapshot.mileageLogs.append(reading)
        snapshot.mileageLogs.sort { $0.recordedAt > $1.recordedAt }
        recomputeMileage(for: draft.vehicleID)
    }

    func deleteMaintenanceLog(id: UUID, photoPaths: [String]) async throws {
        guard let log = snapshot.logs.first(where: { $0.id == id }) else { throw BackendError.nothingDeleted }
        snapshot.logs.removeAll { $0.id == id }
        snapshot.photos.removeAll { $0.maintenanceLogID == id }
        recomputeMileage(for: log.vehicleID)
    }

    func photoURLs(for paths: [String]) async throws -> [String: URL] { [:] }

    /// A small made-up manual, so zoom and search can be tried in demo mode.
    func manualURL(for vehicle: Vehicle) async throws -> URL {
        guard vehicle.manualUploadedAt != nil else { throw BackendError.noManual }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-manual.pdf")
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let topics = ["Engine oil", "Tire pressure", "Brake fluid", "Coolant", "Battery", "Wiper blades", "Cabin air filter", "Towing"]
        let data = UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            for number in 1...24 {
                context.beginPage()
                let topic = topics[(number - 1) % topics.count]
                "Demo owner's manual · page \(number)".draw(at: CGPoint(x: 48, y: 48), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 22)])
                "\(topic): check it every 5,000 miles or 6 months. Replace the \(topic.lowercased()) if it looks worn.\n\nThis page is sample text for trying the zoom buttons and search."
                    .draw(in: CGRect(x: 48, y: 96, width: 516, height: 600), withAttributes: [.font: UIFont.systemFont(ofSize: 15)])
            }
        }
        try data.write(to: url)
        return url
    }

    func saveTrip(_ trip: RecordedTrip) async throws {
        trips.removeAll { $0.id == trip.id }
        trips.append(trip.summary)
        trips.sort { $0.startedAt > $1.startedAt }
    }

    func saveTripReadings(_ samples: [TripSample], for trip: RecordedTrip) async throws {}

    func logTripMileage(id: UUID, vehicleID: UUID, mileage: Int, note: String, recordedAt: Date) async throws {
        guard !snapshot.mileageLogs.contains(where: { $0.id == id }) else { return }
        snapshot.mileageLogs.append(MileageLog(id: id, userID: DemoData.userID, vehicleID: vehicleID, mileage: mileage, note: note, recordedAt: recordedAt))
        snapshot.mileageLogs.sort { $0.recordedAt > $1.recordedAt }
        recomputeMileage(for: vehicleID)
    }

    func loadTrips(limit: Int) async throws -> [Trip] { Array(trips.prefix(limit)) }

    func recordTroubleCodes(vehicleID: UUID, codes: [String]) async throws {}

    func markTroubleCodesCleared(vehicleID: UUID) async throws { demoCodes.removeAll { $0.vehicleID == vehicleID } }

    func reconcileTroubleCodes(vehicleID: UUID, codes: [String]) async throws {
        demoCodes.removeAll { $0.vehicleID == vehicleID }
        demoCodes += codes.map { OpenTroubleCode(vehicleID: vehicleID, code: $0) }
    }

    func loadOpenTroubleCodes() async throws -> [OpenTroubleCode] { demoCodes }

    /// Stands in for the database trigger: the vehicle's odometer follows its newest reading by date.
    private func recomputeMileage(for vehicleID: UUID) {
        guard let index = snapshot.vehicles.firstIndex(where: { $0.id == vehicleID }) else { return }
        let readings = snapshot.logs.filter { $0.vehicleID == vehicleID }.map { ($0.performedAt, $0.mileageAt) }
            + snapshot.mileageLogs.filter { $0.vehicleID == vehicleID }.map { ($0.recordedAt, $0.mileage) }
        guard let latest = readings.max(by: { ($0.0, $0.1) < ($1.0, $1.1) }) else { return }
        snapshot.vehicles[index].currentMileage = latest.1
        snapshot.vehicles[index].mileageUpdatedAt = latest.0
    }
}

struct DemoAuthService: AuthService {
    func userChanges() -> AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            continuation.yield(AuthUser(id: DemoData.userID, email: "demo@garage.app"))
        }
    }

    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
}

enum DemoData {
    static let userID = UUID(uuidString: "00000000-0000-4000-8000-0000000000AA")!

    static func snapshot(now: Date) -> GarageSnapshot {
        func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }
        func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", n))! }

        let tacoma = Vehicle(
            id: id(1), userID: userID, name: "Buddy", make: "Toyota", model: "TRD Sport", year: 2024,
            color: "#e6d3c1", icon: "truck", currentMileage: 11_400, manualUploadedAt: daysAgo(30), mileageUpdatedAt: daysAgo(3),
            avgDailyMiles: 32, sortOrder: 0, createdAt: daysAgo(400)
        )
        let rav4 = Vehicle(
            id: id(2), userID: userID, name: "RAV4", make: "Toyota", model: "RAV4 XLE", year: 2022,
            color: "#0a84ff", icon: "car", currentMileage: 41_230, mileageUpdatedAt: daysAgo(10),
            avgDailyMiles: 22, sortOrder: 1, createdAt: daysAgo(900)
        )

        func type(_ n: Int, _ name: String, _ category: MaintenanceCategory, _ icon: String,
                  miles: Int? = nil, days: Int? = nil, vehicle: UUID? = nil, baseline: Date? = nil) -> MaintenanceType {
            MaintenanceType(
                id: id(n), userID: userID, vehicleID: vehicle, name: name, category: category, icon: icon,
                intervalMiles: miles, intervalDays: days, baselineMileage: baseline == nil ? nil : 0,
                baselineDate: baseline, createdAt: daysAgo(400)
            )
        }
        let types = [
            type(10, "Oil & Filter Change", .oil, "droplet", miles: 5_000, days: 180),
            type(11, "Tire Rotation", .tires, "circle-dot", miles: 5_000, days: 180),
            type(12, "Car Wash", .wash, "sparkles", days: 14),
            type(13, "Brake Inspection", .inspection, "clipboard-check", miles: 5_000, days: 180),
            type(14, "Cabin Air Filter", .custom, "wrench", miles: 30_000),
            type(15, "Battery Check", .inspection, "clipboard-check", days: 365, vehicle: id(1), baseline: daysAgo(400)),
        ]

        func log(_ n: Int, _ vehicle: Int, _ type: Int, _ title: String, _ mileage: Int, _ days: Double,
                 cost: Double? = nil, notes: String = "") -> MaintenanceLog {
            MaintenanceLog(
                id: id(n), userID: userID, vehicleID: id(vehicle), maintenanceTypeID: id(type), title: title,
                notes: notes, cost: cost, mileageAt: mileage, performedAt: daysAgo(days)
            )
        }
        let logs = [
            log(100, 1, 12, "Car Wash", 11_300, 9, cost: 18),
            log(101, 1, 10, "Oil & Filter Change", 8_600, 105, cost: 82, notes: "Synthetic 0W-20, dealer"),
            log(102, 1, 11, "Tire Rotation", 8_600, 105, cost: 25),
            log(103, 1, 13, "Brake Inspection", 8_600, 105),
            log(104, 1, 10, "Oil & Filter Change", 3_900, 250, cost: 74),
            log(105, 2, 10, "Oil & Filter Change", 38_000, 220, cost: 65),
            log(106, 2, 12, "Car Wash", 41_000, 20, cost: 20),
        ].sorted { $0.performedAt > $1.performedAt }

        func reading(_ n: Int, _ vehicle: Int, _ mileage: Int, _ days: Double) -> MileageLog {
            MileageLog(id: id(n), userID: userID, vehicleID: id(vehicle), mileage: mileage, recordedAt: daysAgo(days))
        }
        let mileageLogs = [
            reading(200, 1, 11_400, 3), reading(201, 1, 10_350, 40), reading(202, 1, 9_500, 70),
            reading(203, 1, 7_700, 135), reading(204, 1, 6_600, 165), reading(205, 1, 5_300, 200),
            reading(206, 1, 0, 400),
            reading(207, 2, 41_230, 10), reading(208, 2, 39_500, 140),
        ]

        return GarageSnapshot(vehicles: [tacoma, rav4], types: types, logs: logs, mileageLogs: mileageLogs, photos: [])
    }
}
#endif
