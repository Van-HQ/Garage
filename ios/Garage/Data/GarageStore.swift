import Foundation
import GarageCore
import Observation

/// The app's single source of loaded data. Views read `snapshot` and call
/// `refresh()`; writes go through here so the data reloads afterwards.
@MainActor
@Observable
final class GarageStore {
    private(set) var snapshot = GarageSnapshot()
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    var loadError: String?
    /// Trouble codes the car reported that are still open. Empty if the tables aren't set up.
    private(set) var openCodes: [OpenTroubleCode] = []

    let backend: GarageBackend

    init(backend: GarageBackend) {
        self.backend = backend
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await backend.loadSnapshot()
            loadError = nil
            hasLoaded = true
            await refreshOpenCodes()
        } catch is CancellationError {
            // A newer refresh replaced this one.
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Clears everything on sign-out so the next account never sees stale rows.
    func reset() {
        snapshot = GarageSnapshot()
        hasLoaded = false
        loadError = nil
        openCodes = []
    }

    /// A bonus on top of the main data: if the OBD tables are missing, the rest of the app still works.
    func refreshOpenCodes() async {
        openCodes = (try? await backend.loadOpenTroubleCodes()) ?? []
    }

    func openCodes(for vehicle: Vehicle) -> [String] {
        openCodes.filter { $0.vehicleID == vehicle.id }.map(\.code).sorted()
    }

    func logMaintenance(_ draft: MaintenanceDraft, photos: [Data]) async throws -> Int {
        let failedPhotos = try await backend.logMaintenance(draft, photos: photos)
        await refresh()
        return failedPhotos
    }

    func logMileage(_ draft: MileageDraft) async throws {
        try await backend.logMileage(draft)
        await refresh()
    }

    func delete(_ log: MaintenanceLog) async throws {
        try await backend.deleteMaintenanceLog(id: log.id, photoPaths: photos(for: log).map(\.storagePath))
        await refresh()
    }

    // MARK: Derived data

    /// Buddy comes first everywhere, so it is the default pick on every screen; the rest keep their order.
    var vehicles: [Vehicle] {
        let isBuddy: (Vehicle) -> Bool = { $0.name.caseInsensitiveCompare("Buddy") == .orderedSame }
        return snapshot.vehicles.filter(isBuddy) + snapshot.vehicles.filter { !isBuddy($0) }
    }

    func types(for vehicle: Vehicle) -> [MaintenanceType] {
        snapshot.types.filter { $0.vehicleID == nil || $0.vehicleID == vehicle.id }
    }

    func status(for vehicle: Vehicle, now: Date = Date()) -> [MaintenanceStatusItem] {
        computeMaintenanceStatus(vehicle: vehicle, types: snapshot.types, logs: snapshot.logs, now: now)
    }

    func trend(for vehicle: Vehicle) -> [TrendPoint] {
        computeMileageTrend(vehicle: vehicle, logs: snapshot.logs, mileageLogs: snapshot.mileageLogs)
    }

    func logs(for vehicle: Vehicle) -> [MaintenanceLog] {
        snapshot.logs.filter { $0.vehicleID == vehicle.id }
    }

    func photos(for log: MaintenanceLog) -> [MaintenancePhoto] {
        snapshot.photos.filter { $0.maintenanceLogID == log.id }
    }

    func type(for log: MaintenanceLog) -> MaintenanceType? {
        guard let id = log.maintenanceTypeID else { return nil }
        return snapshot.types.first { $0.id == id }
    }
}
