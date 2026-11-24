import Foundation
import GarageCore

/// A finished trip waiting to reach Supabase, with how far its upload got.
/// Each step records its own progress, so a dropped connection resumes where it
/// stopped instead of starting over (and every step is safe to repeat anyway).
struct PendingTrip: Codable, Identifiable, Equatable {
    var trip: RecordedTrip
    /// The odometer reading to log for this trip's end, or nil to skip the odometer entry.
    var odometerAfter: Int?
    var mileageLogID = UUID()
    var tripSaved = false
    var samplesSaved = 0
    var mileageLogged = false
    var lastError: String?

    var id: UUID { trip.id }
}

/// Trips that haven't been uploaded yet, kept on disk so they survive a relaunch,
/// a dead battery, or a drive with no signal.
actor TripQueue {
    private let fileURL: URL
    private var items: [PendingTrip]

    init(fileURL: URL = TripQueue.defaultFileURL) {
        self.fileURL = fileURL
        self.items = (try? JSONDecoder().decode([PendingTrip].self, from: Data(contentsOf: fileURL))) ?? []
    }

    static var defaultFileURL: URL {
        let folder = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return folder.appendingPathComponent("pending-trips.json")
    }

    func all() -> [PendingTrip] { items }

    func add(_ item: PendingTrip) {
        items.removeAll { $0.id == item.id }
        items.append(item)
        save()
    }

    func update(_ item: PendingTrip) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// Throws away everything waiting, without uploading it.
    func clear() {
        items = []
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        // Atomic, so a crash mid-write can't leave a half-written queue.
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
