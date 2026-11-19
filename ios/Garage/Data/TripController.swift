import Foundation
import GarageCore
import Observation

/// Turns the live OBD stream into saved trips: records them as they happen,
/// queues each finished trip on disk, and uploads the queue whenever it can.
@MainActor
@Observable
final class TripController {
    /// The trip being recorded right now, if any.
    private(set) var progress: TripRecorder.Progress?
    /// Finished trips not yet uploaded.
    private(set) var pending: [PendingTrip] = []
    private(set) var isSyncing = false
    /// Why the last upload attempt failed, in plain words. Nil when the last attempt worked.
    private(set) var syncProblem: String?

    private let obd: OBDSession
    private let store: GarageStore
    private let queue: TripQueue
    private var recorder: TripRecorder?
    private static let vehicleKey = "drive.vehicleID"

    /// The vehicle being driven. Defaults to the first one; remembered between launches.
    var vehicleID: UUID? {
        didSet { UserDefaults.standard.set(vehicleID?.uuidString, forKey: Self.vehicleKey) }
    }

    init(obd: OBDSession, store: GarageStore, queue: TripQueue = TripQueue()) {
        self.obd = obd
        self.store = store
        self.queue = queue
        self.vehicleID = UserDefaults.standard.string(forKey: Self.vehicleKey).flatMap(UUID.init(uuidString:))

        obd.onReadings = { [weak self] readings in self?.handle(readings) }
        obd.onDisconnect = { [weak self] in self?.finishCurrentTrip() }
        Task { [weak self] in
            guard let self else { return }
            self.pending = await self.queue.all()
        }
    }

    var vehicle: Vehicle? {
        store.vehicles.first { $0.id == vehicleID } ?? store.vehicles.first
    }

    var isRecording: Bool { progress != nil }

    // MARK: Recording

    private func handle(_ readings: [OBDReading]) {
        guard let vehicle else { return }
        if recorder?.vehicleID != vehicle.id {
            // Only reachable between trips: the picker is locked while one is recording.
            recorder = TripRecorder(vehicleID: vehicle.id)
        }
        let finished = recorder?.ingest(readings)
        progress = recorder?.progress
        if let finished { enqueue(finished) }
    }

    /// The user tapped End, or the adapter went away.
    func finishCurrentTrip() {
        guard let finished = recorder?.finish() else {
            progress = nil
            return
        }
        progress = nil
        enqueue(finished)
    }

    private func enqueue(_ trip: RecordedTrip) {
        // The odometer after this trip: the latest known reading plus the trip, or
        // the latest pending trip's reading if that is higher (several trips can
        // queue up offline, and each must build on the one before).
        let known = store.vehicles.first { $0.id == trip.vehicleID }?.currentMileage
        let queued = pending.filter { $0.trip.vehicleID == trip.vehicleID }.compactMap(\.odometerAfter).max()
        let base = [known, queued].compactMap { $0 }.max()
        let item = PendingTrip(trip: trip, odometerAfter: base.map { $0 + Int(trip.distanceMiles.rounded()) })

        pending.append(item)
        Task {
            await queue.add(item)
            await syncPending()
        }
    }

    // MARK: Uploading

    /// Uploads whatever is waiting. Safe to call any time, including while already uploading.
    func syncPending() async {
        guard !isSyncing else { return }
        pending = await queue.all()
        guard !pending.isEmpty else { return }

        isSyncing = true
        defer { isSyncing = false }

        var uploadedAny = false
        for var item in pending {
            do {
                try await upload(&item)
                await queue.remove(id: item.id)
                uploadedAny = true
                syncProblem = nil
            } catch {
                item.lastError = error.localizedDescription
                await queue.update(item)
                syncProblem = Self.friendly(error)
                break
            }
        }
        pending = await queue.all()
        if uploadedAny { await store.refresh() }
    }

    private func upload(_ item: inout PendingTrip) async throws {
        let backend = store.backend
        let trip = item.trip

        if !item.tripSaved {
            try await backend.saveTrip(trip)
            item.tripSaved = true
            await queue.update(item)
        }

        let chunkSize = 500
        while item.samplesSaved < trip.samples.count {
            let end = min(item.samplesSaved + chunkSize, trip.samples.count)
            try await backend.saveTripReadings(Array(trip.samples[item.samplesSaved..<end]), for: trip)
            item.samplesSaved = end
            await queue.update(item)
        }

        if let odometer = item.odometerAfter, !item.mileageLogged {
            let miles = trip.distanceMiles.formatted(.number.precision(.fractionLength(1)))
            try await backend.logTripMileage(
                id: item.mileageLogID, vehicleID: trip.vehicleID, mileage: odometer,
                note: "Trip: \(miles) mi (OBD)", recordedAt: trip.endedAt
            )
            item.mileageLogged = true
            await queue.update(item)
        }
    }

    /// A missing table is the one failure with a known fix, so say so.
    static func friendly(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("schema cache") || text.contains("does not exist") {
            return "The trip tables aren't set up in Supabase yet. Run the OBD section of supabase/schema.sql, then retry."
        }
        return text
    }
}
