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
