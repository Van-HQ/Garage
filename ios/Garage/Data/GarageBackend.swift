import Foundation
import GarageCore

/// Everything the app shows, loaded in one go (the web app's useGarageData does the same).
struct GarageSnapshot: Sendable {
    var vehicles: [Vehicle] = []
    var types: [MaintenanceType] = []
    /// Newest first.
    var logs: [MaintenanceLog] = []
    /// Newest first.
    var mileageLogs: [MileageLog] = []
    var photos: [MaintenancePhoto] = []
}

struct MaintenanceDraft: Sendable {
    var vehicleID: UUID
    var typeID: UUID?
    var title: String
    var notes: String
    var cost: Double?
    var mileage: Int
    var performedAt: Date
}

struct MileageDraft: Sendable {
    var vehicleID: UUID
    var mileage: Int
    var note: String
    var recordedAt: Date
}

struct AuthUser: Equatable, Sendable {
    var id: UUID
    var email: String?
}

/// Sign-in. One implementation talks to Supabase, the other is the built-in demo.
protocol AuthService: Sendable {
    /// Emits the current user right away (nil when signed out), then again on every change.
    func userChanges() -> AsyncStream<AuthUser?>
    func signIn(email: String, password: String) async throws
    func signOut() async throws
}

/// Data access. Views and stores only ever see this protocol, so the whole app
/// runs unchanged on the demo data (previews, `-demo` launches, UI checks).
protocol GarageBackend: Sendable {
    func loadSnapshot() async throws -> GarageSnapshot

    /// Saves the log, then uploads its photos (JPEG data). Returns how many
    /// photos failed to upload; the log itself is saved either way, as on the web.
    func logMaintenance(_ draft: MaintenanceDraft, photos: [Data]) async throws -> Int

    /// Odometer readings always go through mileage_logs. The database triggers
    /// recompute the vehicle's current mileage; the app never sets it directly.
    func logMileage(_ draft: MileageDraft) async throws

    /// Short-lived signed URLs for private maintenance photos, keyed by storage path.
    func photoURLs(for paths: [String]) async throws -> [String: URL]

    /// Short-lived signed URL for a vehicle's owner's manual PDF.
    func manualURL(for vehicle: Vehicle) async throws -> URL

    // MARK: OBD (needs the trips / obd_readings / dtc_events tables from supabase/schema.sql)

    /// Saves the trip's summary row. Safe to repeat: the trip's id is chosen by the app.
    func saveTrip(_ trip: RecordedTrip) async throws

    /// Saves a batch of a trip's samples. Safe to repeat: duplicates are ignored.
    func saveTripReadings(_ samples: [TripSample], for trip: RecordedTrip) async throws

    /// Writes a trip's distance as an odometer reading. Safe to repeat: `id` is chosen by the app.
    func logTripMileage(id: UUID, vehicleID: UUID, mileage: Int, note: String, recordedAt: Date) async throws

    /// Newest first.
    func loadTrips(limit: Int) async throws -> [Trip]

    /// Remembers codes the vehicle reported. Codes already open for this vehicle aren't added twice.
    func recordTroubleCodes(vehicleID: UUID, codes: [String]) async throws

    /// Marks this vehicle's open codes as cleared.
    func markTroubleCodesCleared(vehicleID: UUID) async throws
}

enum BackendError: LocalizedError {
    case notSignedIn
    case noManual

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "You're signed out. Please sign in again."
        case .noManual: "This vehicle has no owner's manual yet. Upload one from the web app."
        }
    }
}
