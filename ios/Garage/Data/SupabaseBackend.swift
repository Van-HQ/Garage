import Foundation
import GarageCore
import Supabase

/// Builds the one Supabase client the app uses. It holds only the publishable key.
func makeSupabaseClient(config: AppConfig) -> SupabaseClient {
    SupabaseClient(
        supabaseURL: config.supabaseURL,
        supabaseKey: config.supabaseKey,
        options: SupabaseClientOptions(
            // Report the saved session straight away at launch (also when
            // offline). The SDK refreshes an expired one on the next request.
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}

struct SupabaseAuthService: AuthService {
    let client: SupabaseClient

    func userChanges() -> AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            let task = Task {
                for await change in client.auth.authStateChanges {
                    let user = change.session.map { AuthUser(id: $0.user.id, email: $0.user.email) }
                    continuation.yield(user)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        // Local scope: sign out this phone only, not the web app's session.
        try await client.auth.signOut(scope: .local)
    }
}

/// Reads and writes the existing tables and buckets, mirroring the queries in
/// the web app's src/lib/useGarageData.ts and src/app/log/page.tsx.
struct SupabaseBackend: GarageBackend {
    let client: SupabaseClient

    private static let signedURLLifetime = 3600

    func loadSnapshot() async throws -> GarageSnapshot {
        async let vehicles: [Vehicle] = client.from("vehicles").select()
            .order("sort_order", ascending: true).execute().value
        async let types: [MaintenanceType] = client.from("maintenance_types").select()
            .order("created_at", ascending: true).execute().value
        async let logs: [MaintenanceLog] = client.from("maintenance_logs").select()
            .order("performed_at", ascending: false).execute().value
        async let mileageLogs: [MileageLog] = client.from("mileage_logs").select()
            .order("recorded_at", ascending: false).execute().value
        async let photos: [MaintenancePhoto] = client.from("maintenance_photos").select()
            .order("created_at", ascending: true).execute().value

        return try await GarageSnapshot(
            vehicles: vehicles, types: types, logs: logs, mileageLogs: mileageLogs, photos: photos
        )
    }

    func logMaintenance(_ draft: MaintenanceDraft, photos: [Data]) async throws -> Int {
        let userID = try await currentUserID()

        struct NewLog: Encodable {
            let user_id: UUID
            let vehicle_id: UUID
            let maintenance_type_id: UUID?
            let title: String
            let notes: String
            let cost: Double?
            let mileage_at: Int
            let performed_at: Date
        }
        let inserted: MaintenanceLog = try await client.from("maintenance_logs")
            .insert(NewLog(
                user_id: userID, vehicle_id: draft.vehicleID, maintenance_type_id: draft.typeID,
                title: draft.title, notes: draft.notes, cost: draft.cost,
                mileage_at: draft.mileage, performed_at: draft.performedAt
            ))
            .select().single().execute().value

        struct NewPhoto: Encodable {
            let user_id: UUID
            let maintenance_log_id: UUID
            let storage_path: String
        }
        var failed = 0
        for data in photos {
            // Storage policies compare the first folder with auth.uid()::text,
            // which is lowercase. Swift prints UUIDs in uppercase.
            let path = "\(userID.storagePathComponent)/\(inserted.id.storagePathComponent)/\(UUID().storagePathComponent).jpg"
            do {
                try await client.storage.from("maintenance-photos")
                    .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
                try await client.from("maintenance_photos")
                    .insert(NewPhoto(user_id: userID, maintenance_log_id: inserted.id, storage_path: path))
                    .execute()
            } catch {
                failed += 1
            }
        }
        return failed
    }

    func logMileage(_ draft: MileageDraft) async throws {
        let userID = try await currentUserID()

        struct NewReading: Encodable {
            let user_id: UUID
            let vehicle_id: UUID
            let mileage: Int
            let note: String
            let recorded_at: Date
        }
        try await client.from("mileage_logs")
            .insert(NewReading(
                user_id: userID, vehicle_id: draft.vehicleID, mileage: draft.mileage,
                note: draft.note, recorded_at: draft.recordedAt
            ))
            .execute()
    }

    func deleteMaintenanceLog(id: UUID, photoPaths: [String]) async throws {
        // Ask for the deleted row back, so "nothing was deleted" is an error instead of a silent success.
        struct Deleted: Decodable { let id: UUID }
        let deleted: [Deleted] = try await client.from("maintenance_logs")
            .delete().eq("id", value: id).select("id").execute().value
        guard !deleted.isEmpty else { throw BackendError.nothingDeleted }
        // The entry is gone either way; a photo file left behind is harmless.
        if !photoPaths.isEmpty {
            _ = try? await client.storage.from("maintenance-photos").remove(paths: photoPaths)
        }
    }

    func photoURLs(for paths: [String]) async throws -> [String: URL] {
        guard !paths.isEmpty else { return [:] }
        let results = try await client.storage.from("maintenance-photos")
            .createSignedURLs(paths: paths, expiresIn: Self.signedURLLifetime)
        var urls: [String: URL] = [:]
        for result in results {
            if case let .success(path, signedURL) = result { urls[path] = signedURL }
        }
        return urls
    }

    func manualURL(for vehicle: Vehicle) async throws -> URL {
        guard vehicle.manualUploadedAt != nil else { throw BackendError.noManual }
        let userID = try await currentUserID()
        let path = "\(userID.storagePathComponent)/\(vehicle.id.storagePathComponent).pdf"
        return try await client.storage.from("manuals")
            .createSignedURL(path: path, expiresIn: Self.signedURLLifetime)
    }

    // MARK: OBD

    func saveTrip(_ trip: RecordedTrip) async throws {
        let userID = try await currentUserID()

        struct Row: Encodable {
            let id: UUID
            let user_id: UUID
            let vehicle_id: UUID
            let started_at: Date
            let ended_at: Date
            let distance_miles: Double
            let avg_speed_mph: Double?
            let max_speed_mph: Double?
            let max_rpm: Double?
            let max_coolant_c: Double?
            let fuel_used_pct: Double?
            let distance_source: String
        }
        try await client.from("trips")
            .upsert(
                Row(
                    id: trip.id, user_id: userID, vehicle_id: trip.vehicleID, started_at: trip.startedAt,
                    ended_at: trip.endedAt, distance_miles: trip.distanceMiles, avg_speed_mph: trip.avgSpeedMph,
                    max_speed_mph: trip.maxSpeedMph, max_rpm: trip.maxRPM, max_coolant_c: trip.maxCoolantC,
                    fuel_used_pct: trip.fuelUsedPercent, distance_source: trip.distanceSource
                ),
                onConflict: "id", returning: .minimal
            )
            .execute()
    }

    func saveTripReadings(_ samples: [TripSample], for trip: RecordedTrip) async throws {
        guard !samples.isEmpty else { return }
        let userID = try await currentUserID()

        struct Row: Encodable {
            let user_id: UUID
            let vehicle_id: UUID
            let trip_id: UUID
            let recorded_at: Date
            let pid: Int
            let value: Double
        }
        let rows = samples.map {
            Row(user_id: userID, vehicle_id: trip.vehicleID, trip_id: trip.id, recorded_at: $0.recordedAt, pid: $0.pid, value: $0.value)
        }
        try await client.from("obd_readings")
            .upsert(rows, onConflict: "trip_id,recorded_at,pid", returning: .minimal, ignoreDuplicates: true)
            .execute()
    }

    func logTripMileage(id: UUID, vehicleID: UUID, mileage: Int, note: String, recordedAt: Date) async throws {
        let userID = try await currentUserID()

        struct Row: Encodable {
            let id: UUID
            let user_id: UUID
            let vehicle_id: UUID
            let mileage: Int
            let note: String
            let recorded_at: Date
        }
        try await client.from("mileage_logs")
            .upsert(
                Row(id: id, user_id: userID, vehicle_id: vehicleID, mileage: mileage, note: note, recorded_at: recordedAt),
                onConflict: "id", returning: .minimal, ignoreDuplicates: true
            )
            .execute()
    }

    func loadTrips(limit: Int) async throws -> [Trip] {
        try await client.from("trips").select()
            .order("started_at", ascending: false).limit(limit)
            .execute().value
    }

    func recordTroubleCodes(vehicleID: UUID, codes: [String]) async throws {
        guard !codes.isEmpty else { return }
        let userID = try await currentUserID()

        struct Open: Decodable { let code: String }
        let open: [Open] = try await client.from("dtc_events").select("code")
            .eq("vehicle_id", value: vehicleID)
            .is("cleared_at", value: nil)
            .execute().value
        let known = Set(open.map(\.code))

        struct Row: Encodable {
            let user_id: UUID
            let vehicle_id: UUID
            let code: String
        }
        let fresh = codes.filter { !known.contains($0) }.map { Row(user_id: userID, vehicle_id: vehicleID, code: $0) }
        guard !fresh.isEmpty else { return }
        try await client.from("dtc_events").insert(fresh, returning: .minimal).execute()
    }

    func reconcileTroubleCodes(vehicleID: UUID, codes: [String]) async throws {
        try await recordTroubleCodes(vehicleID: vehicleID, codes: codes)

        struct Open: Decodable { let code: String }
        let open: [Open] = try await client.from("dtc_events").select("code")
            .eq("vehicle_id", value: vehicleID)
            .is("cleared_at", value: nil)
            .execute().value
        let gone = open.map(\.code).filter { !codes.contains($0) }
        guard !gone.isEmpty else { return }
        struct Patch: Encodable { let cleared_at: Date }
        try await client.from("dtc_events")
            .update(Patch(cleared_at: Date()), returning: .minimal)
            .eq("vehicle_id", value: vehicleID)
            .is("cleared_at", value: nil)
            .in("code", values: gone)
            .execute()
    }

    func loadOpenTroubleCodes() async throws -> [OpenTroubleCode] {
        struct Row: Decodable { let vehicle_id: UUID; let code: String }
        let rows: [Row] = try await client.from("dtc_events").select("vehicle_id, code")
            .is("cleared_at", value: nil)
            .execute().value
        return rows.map { OpenTroubleCode(vehicleID: $0.vehicle_id, code: $0.code) }
    }

    func markTroubleCodesCleared(vehicleID: UUID) async throws {
        struct Patch: Encodable { let cleared_at: Date }
        try await client.from("dtc_events")
            .update(Patch(cleared_at: Date()), returning: .minimal)
            .eq("vehicle_id", value: vehicleID)
            .is("cleared_at", value: nil)
            .execute()
    }

    private func currentUserID() async throws -> UUID {
        do {
            return try await client.auth.session.user.id
        } catch {
            throw BackendError.notSignedIn
        }
    }
}

private extension UUID {
    /// Lowercase, the way Postgres and the web app write UUIDs into storage paths.
    var storagePathComponent: String { uuidString.lowercased() }
}
